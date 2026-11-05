import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../domain/models/tenant_model.dart';
import '../../domain/models/venta_model.dart';

/// Generador mínimo de comandos ESC/POS (impresoras térmicas de tickets).
/// Solo incluye lo necesario: texto, alineación, negritas, tamaño, QR,
/// corte de papel y pulso para abrir el cajón de dinero.
class EscPos {
  final List<int> _b = [];
  final int cols;

  EscPos({required int paperWidthMm}) : cols = paperWidthMm <= 58 ? 32 : 48 {
    _b.addAll([0x1B, 0x40]); // ESC @  reset
    _b.addAll([0x1B, 0x74, 19]); // ESC t 19  página de códigos CP858 (español)
  }

  Uint8List get bytes => Uint8List.fromList(_b);

  // Caracteres CP858 más comunes en español.
  static const Map<String, int> _cp858 = {
    'á': 0xA0, 'é': 0x82, 'í': 0xA1, 'ó': 0xA2, 'ú': 0xA3,
    'ñ': 0xA4, 'Ñ': 0xA5, '¿': 0xA8, '¡': 0xAD, 'ü': 0x81, 'Ü': 0x9A,
    'Á': 0xB5, 'É': 0x90, 'Í': 0xD6, 'Ó': 0xE0, 'Ú': 0xE9,
    '°': 0xF8, '€': 0xD5, '£': 0x9C,
  };

  List<int> _enc(String s) {
    final out = <int>[];
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      if (r < 128) {
        out.add(r);
      } else {
        out.add(_cp858[ch] ?? 0x3F); // '?'
      }
    }
    return out;
  }

  EscPos align(int a) { // 0 izq, 1 centro, 2 der
    _b.addAll([0x1B, 0x61, a]);
    return this;
  }

  EscPos bold(bool on) {
    _b.addAll([0x1B, 0x45, on ? 1 : 0]);
    return this;
  }

  /// Tamaño: 1 = normal, 2 = doble alto y ancho.
  EscPos size(int s) {
    _b.addAll([0x1D, 0x21, s >= 2 ? 0x11 : 0x00]);
    return this;
  }

  EscPos text(String s) {
    _b.addAll(_enc(s));
    _b.add(0x0A);
    return this;
  }

  EscPos line() => text('-' * cols);

  /// Texto a izquierda y derecha en la misma línea.
  EscPos row(String left, String right) {
    final space = cols - left.length - right.length;
    if (space >= 1) {
      return text('$left${' ' * space}$right');
    }
    text(left);
    return align(2).text(right).align(0);
  }

  EscPos feed(int n) {
    _b.addAll([0x1B, 0x64, n]);
    return this;
  }

  EscPos qr(String data, {int moduleSize = 5}) {
    final d = _enc(data);
    final len = d.length + 3;
    _b.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]); // modelo 2
    _b.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize]); // tamaño
    _b.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]); // corrección M
    _b.addAll([0x1D, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x31, 0x50, 0x30]);
    _b.addAll(d);
    _b.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]); // imprimir
    return this;
  }

  EscPos cut() {
    _b.addAll([0x1D, 0x56, 0x42, 0x00]); // corte parcial con avance
    return this;
  }

  /// Pulso para abrir el cajón conectado al puerto de la impresora.
  /// [pin]: 0 = pin 2 (el más común), 1 = pin 5.
  EscPos openDrawer({int pin = 0}) {
    _b.addAll([0x1B, 0x70, pin == 1 ? 1 : 0, 0x32, 0x32]);
    return this;
  }

  /// Arma el ticket de venta completo.
  static Uint8List receipt({
    required VentaModel venta,
    required NumberFormat fmt,
    required int paperWidthMm,
    TenantModel? tenant,
    double? efectivoRecibido,
    bool openDrawer = false,
    int drawerPin = 0,
  }) {
    final p = EscPos(paperWidthMm: paperWidthMm);
    final folio = venta.id.length >= 8
        ? venta.id.substring(0, 8).toUpperCase()
        : venta.id.toUpperCase();

    if (openDrawer) p.openDrawer(pin: drawerPin);

    p.align(1).bold(true).size(2).text(tenant?.nombre ?? 'Punto de Venta');
    p.size(1).bold(false);
    if ((tenant?.direccion ?? '').isNotEmpty) p.text(tenant!.direccion!);
    if ((tenant?.telefono ?? '').isNotEmpty) p.text('Tel: ${tenant!.telefono}');
    p.align(0).line();
    p.row('Folio: $folio', DateFormat('dd/MM/yy HH:mm').format(venta.fecha));
    p.line();

    for (final d in venta.detalles) {
      p.bold(true).text(d.insumoNombre ?? 'Producto').bold(false);
      p.row('  ${d.cantidad.toInt()} x ${fmt.format(d.precioVentaUnitario)}',
          fmt.format(d.total));
    }
    p.line();
    p.bold(true).row('TOTAL', fmt.format(venta.totalIngresos)).bold(false);

    if (efectivoRecibido != null && efectivoRecibido > 0) {
      final cambio = efectivoRecibido - venta.totalIngresos;
      p.row('Recibido', fmt.format(efectivoRecibido));
      p.row('Cambio', fmt.format(cambio < 0 ? 0 : cambio));
    }
    p.line();
    p.align(1).bold(true).text(tenant?.mensajeRecibo ?? '¡Gracias por su compra!').bold(false);
    p.feed(1).qr(venta.id).feed(4).cut();
    return p.bytes;
  }

  /// Ticket de prueba para verificar la conexión.
  static Uint8List testTicket({
    required int paperWidthMm,
    bool openDrawer = false,
    int drawerPin = 0,
  }) {
    final p = EscPos(paperWidthMm: paperWidthMm);
    if (openDrawer) p.openDrawer(pin: drawerPin);
    p.align(1).bold(true).size(2).text('PRUEBA').size(1).bold(false);
    p.text('Impresora conectada correctamente');
    p.text('áéíóú ñ ¿? ¡! \$ 123,456.78');
    p.line().qr('PRUEBA-IMPRESORA').feed(4).cut();
    return p.bytes;
  }

  static Uint8List drawerOnly({int pin = 0}) =>
      (EscPos(paperWidthMm: 80)..openDrawer(pin: pin)).bytes;
}
