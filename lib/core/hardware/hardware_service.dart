import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import '../../domain/models/tenant_model.dart';
import '../../domain/models/venta_model.dart';
import '../utils/receipt_pdf.dart';
import 'escpos.dart';
import 'hardware_settings.dart';

enum PrinterStatus {
  /// No hay impresora configurada en esta terminal.
  notConfigured,

  /// Impresora detectada/alcanzable: se puede imprimir sin preguntar.
  ready,

  /// No se puede verificar (navegador o móvil): solo impresión manual
  /// mediante el diálogo del sistema.
  unverified,

  /// Está configurada pero no responde.
  offline,
}

class HardwareResult {
  final bool ok;
  final String message;
  const HardwareResult(this.ok, this.message);
}

/// Controla la impresora de tickets, el cajón de dinero y la configuración
/// del lector de códigos de esta terminal.
class HardwareService extends ChangeNotifier {
  HardwareSettings _settings = const HardwareSettings();
  PrinterStatus _status = PrinterStatus.notConfigured;
  String _statusDetail = 'Sin impresora configurada';
  List<Printer> _systemPrinters = const [];
  bool _checking = false;

  HardwareSettings get settings => _settings;
  PrinterStatus get status => _status;
  String get statusDetail => _statusDetail;
  List<Printer> get systemPrinters => _systemPrinters;
  bool get checking => _checking;

  /// Se puede ofrecer el botón Imprimir.
  bool get canPrintManually =>
      _status == PrinterStatus.ready || _status == PrinterStatus.unverified;

  /// Se puede imprimir sola, sin diálogos, al cobrar.
  bool get canAutoPrint => _status == PrinterStatus.ready;

  /// El cajón se abre con un pulso enviado a la impresora: solo es posible
  /// con impresora de red ESC/POS.
  bool get drawerSupported =>
      _settings.printerConnection == PrinterConnection.network;

  static bool get supportsNetwork => !kIsWeb;

  static bool get supportsSystemList =>
      !kIsWeb && (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux);

  Future<void> load() async {
    _settings = await HardwareSettings.load();
    await refreshStatus();
  }

  Future<void> update(HardwareSettings next) async {
    _settings = next;
    notifyListeners();
    await next.save();
    await refreshStatus();
  }

  // ------------------------------------------------------------------
  // Estado de la impresora
  // ------------------------------------------------------------------

  Future<void> refreshSystemPrinters() async {
    if (!supportsSystemList) return;
    try {
      _systemPrinters = await Printing.listPrinters();
    } catch (_) {
      _systemPrinters = const [];
    }
    notifyListeners();
  }

  Future<PrinterStatus> refreshStatus() async {
    _checking = true;
    notifyListeners();
    try {
      switch (_settings.printerConnection) {
        case PrinterConnection.none:
          _status = PrinterStatus.notConfigured;
          _statusDetail = 'Sin impresora configurada';
          break;

        case PrinterConnection.system:
          if (supportsSystemList) {
            await refreshSystemPrinters();
            final url = _settings.systemPrinterUrl;
            if (url == null) {
              _status = PrinterStatus.offline;
              _statusDetail = 'Elige una impresora de la lista';
            } else {
              final match = _systemPrinters.where((p) => p.url == url);
              if (match.isNotEmpty && match.first.isAvailable) {
                _status = PrinterStatus.ready;
                _statusDetail = 'Conectada: ${match.first.name}';
              } else {
                _status = PrinterStatus.offline;
                _statusDetail = match.isEmpty
                    ? 'No se detecta "${_settings.systemPrinterName ?? 'la impresora'}". ¿Está conectada y encendida?'
                    : '"${match.first.name}" aparece sin conexión';
              }
            }
          } else {
            _status = PrinterStatus.unverified;
            _statusDetail = kIsWeb
                ? 'Se usará el diálogo de impresión del navegador'
                : 'Se usará el diálogo de impresión del sistema';
          }
          break;

        case PrinterConnection.network:
          if (!supportsNetwork) {
            _status = PrinterStatus.offline;
            _statusDetail = 'La impresión por red no está disponible en el navegador';
          } else if (_settings.networkHost.trim().isEmpty) {
            _status = PrinterStatus.offline;
            _statusDetail = 'Escribe la IP de la impresora';
          } else {
            final ok = await _ping();
            _status = ok ? PrinterStatus.ready : PrinterStatus.offline;
            _statusDetail = ok
                ? 'Conectada: ${_settings.networkHost}:${_settings.networkPort}'
                : 'Sin respuesta de ${_settings.networkHost}:${_settings.networkPort}';
          }
          break;
      }
    } finally {
      _checking = false;
      notifyListeners();
    }
    return _status;
  }

  Future<bool> _ping() async {
    try {
      final s = await io.Socket.connect(
        _settings.networkHost.trim(),
        _settings.networkPort,
        timeout: const Duration(seconds: 2),
      );
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendNetwork(Uint8List bytes) async {
    final s = await io.Socket.connect(
      _settings.networkHost.trim(),
      _settings.networkPort,
      timeout: const Duration(seconds: 3),
    );
    try {
      s.add(bytes);
      await s.flush();
    } finally {
      await s.close();
    }
  }

  PdfPageFormat get _pdfFormat =>
      _settings.paperWidthMm <= 58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  /// Imprime el ticket. Nunca imprime si no hay una impresora conectada.
  /// [manual] = el cajero pulsó "Imprimir" (permite el diálogo del sistema).
  Future<HardwareResult> printReceipt({
    required VentaModel venta,
    required NumberFormat fmt,
    TenantModel? tenant,
    double? efectivoRecibido,
    bool manual = false,
    bool openDrawer = false,
  }) async {
    if (!_settings.printerConfigured) {
      return const HardwareResult(false, 'No hay impresora configurada.');
    }
    // Verificar de nuevo justo antes de imprimir.
    await refreshStatus();
    if (_status == PrinterStatus.offline || _status == PrinterStatus.notConfigured) {
      return HardwareResult(false, _statusDetail);
    }
    if (_status == PrinterStatus.unverified && !manual) {
      return const HardwareResult(false, 'Impresión automática no disponible en este dispositivo.');
    }

    try {
      if (_settings.printerConnection == PrinterConnection.network) {
        await _sendNetwork(EscPos.receipt(
          venta: venta,
          fmt: fmt,
          tenant: tenant,
          paperWidthMm: _settings.paperWidthMm,
          efectivoRecibido: efectivoRecibido,
          openDrawer: openDrawer,
          drawerPin: _settings.drawerPin,
        ));
        return const HardwareResult(true, 'Ticket enviado a la impresora.');
      }

      Future<Uint8List> pdf(_) => ReceiptPdf.build(
            venta: venta,
            fmt: fmt,
            tenant: tenant,
            efectivoRecibido: efectivoRecibido,
            paperWidthMm: _settings.paperWidthMm,
          );
      final name = 'Ticket_${ReceiptPdf.folio(venta)}';

      final url = _settings.systemPrinterUrl;
      if (supportsSystemList && url != null) {
        await Printing.directPrintPdf(
          printer: Printer(url: url, name: _settings.systemPrinterName ?? url),
          onLayout: pdf,
          name: name,
          format: _pdfFormat,
        );
      } else {
        await Printing.layoutPdf(onLayout: pdf, name: name, format: _pdfFormat);
      }
      return const HardwareResult(true, 'Ticket enviado a imprimir.');
    } catch (e) {
      return HardwareResult(false, 'No se pudo imprimir: $e');
    }
  }

  Future<HardwareResult> openDrawer() async {
    if (!drawerSupported) {
      return const HardwareResult(
          false, 'El cajón se abre desde una impresora de red ESC/POS.');
    }
    try {
      await _sendNetwork(EscPos.drawerOnly(pin: _settings.drawerPin));
      return const HardwareResult(true, 'Cajón abierto.');
    } catch (e) {
      return HardwareResult(false, 'No se pudo abrir el cajón: $e');
    }
  }

  Future<HardwareResult> testPrint({bool withDrawer = false}) async {
    await refreshStatus();
    if (_status == PrinterStatus.offline || _status == PrinterStatus.notConfigured) {
      return HardwareResult(false, _statusDetail);
    }
    try {
      if (_settings.printerConnection == PrinterConnection.network) {
        await _sendNetwork(EscPos.testTicket(
          paperWidthMm: _settings.paperWidthMm,
          openDrawer: withDrawer,
          drawerPin: _settings.drawerPin,
        ));
      } else {
        // Ticket de prueba como PDF mínimo.
        final venta = VentaModel(
          id: 'PRUEBA000',
          fecha: DateTime.now(),
          totalIngresos: 0,
          totalCostos: 0,
          gananciaNeta: 0,
          detalles: const [],
        );
        Future<Uint8List> pdf(_) => ReceiptPdf.build(
              venta: venta,
              fmt: NumberFormat.currency(locale: 'es_MX', symbol: '\$'),
              paperWidthMm: _settings.paperWidthMm,
            );
        final url = _settings.systemPrinterUrl;
        if (supportsSystemList && url != null) {
          await Printing.directPrintPdf(
            printer: Printer(url: url, name: _settings.systemPrinterName ?? url),
            onLayout: pdf,
            name: 'Prueba',
            format: _pdfFormat,
          );
        } else {
          await Printing.layoutPdf(onLayout: pdf, name: 'Prueba', format: _pdfFormat);
        }
      }
      return const HardwareResult(true, 'Página de prueba enviada.');
    } catch (e) {
      return HardwareResult(false, 'No se pudo imprimir la prueba: $e');
    }
  }

  /// Se llama al terminar una venta guardada. Imprime y abre el cajón solo si
  /// la terminal lo tiene configurado Y el equipo está conectado.
  /// Devuelve avisos para mostrar al cajero (no bloquea la venta).
  Future<List<HardwareResult>> onSaleCompleted({
    required VentaModel venta,
    required NumberFormat fmt,
    TenantModel? tenant,
    double? efectivoRecibido,
  }) async {
    final results = <HardwareResult>[];
    final wantsPrint = _settings.autoPrint && _settings.printerConfigured;
    final wantsDrawer = _settings.openDrawerOnSale && drawerSupported;

    if (wantsPrint) {
      final r = await printReceipt(
        venta: venta,
        fmt: fmt,
        tenant: tenant,
        efectivoRecibido: efectivoRecibido,
        openDrawer: wantsDrawer,
      );
      if (!r.ok) results.add(r);
      // Si se imprimió por red, el pulso del cajón ya viajó con el ticket.
      if (r.ok && wantsDrawer) return results;
    }
    if (wantsDrawer && (!wantsPrint || results.isNotEmpty)) {
      final r = await openDrawer();
      if (!r.ok) results.add(r);
    }
    return results;
  }
}
