import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se conecta la impresora de tickets a ESTA terminal.
enum PrinterConnection {
  /// No hay impresora: el ticket solo se ve en pantalla.
  none,

  /// Impresora instalada en el sistema (Windows/macOS/Linux) o diálogo de
  /// impresión del navegador/teléfono.
  system,

  /// Impresora térmica ESC/POS en red (IP y puerto, normalmente 9100).
  network,
}

/// Configuración de los equipos de caja. Es POR TERMINAL (no por empresa):
/// cada computadora o tablet tiene su propia impresora y su propio lector,
/// por eso se guarda en el dispositivo y no en la base de datos.
class HardwareSettings {
  // --- Impresora de tickets ---
  final PrinterConnection printerConnection;
  final String? systemPrinterUrl; // Printer.url
  final String? systemPrinterName;
  final String networkHost;
  final int networkPort;
  final int paperWidthMm; // 58 u 80
  final bool autoPrint; // imprimir solo al cobrar
  final bool showReceiptOnScreen;

  // --- Cajón de dinero (conectado a la impresora) ---
  final bool openDrawerOnSale;
  final int drawerPin; // 0 = pin 2, 1 = pin 5

  // --- Lector de código de barras / QR ---
  final bool scannerEnabled;
  final bool scannerAutoAdd;
  final int scannerMinLength;
  final bool scannerFocusOnOpen;

  const HardwareSettings({
    this.printerConnection = PrinterConnection.none,
    this.systemPrinterUrl,
    this.systemPrinterName,
    this.networkHost = '',
    this.networkPort = 9100,
    this.paperWidthMm = 80,
    this.autoPrint = false,
    this.showReceiptOnScreen = true,
    this.openDrawerOnSale = false,
    this.drawerPin = 0,
    this.scannerEnabled = true,
    this.scannerAutoAdd = true,
    this.scannerMinLength = 4,
    this.scannerFocusOnOpen = true,
  });

  bool get printerConfigured {
    switch (printerConnection) {
      case PrinterConnection.none:
        return false;
      case PrinterConnection.system:
        return true;
      case PrinterConnection.network:
        return networkHost.trim().isNotEmpty;
    }
  }

  HardwareSettings copyWith({
    PrinterConnection? printerConnection,
    Object? systemPrinterUrl = _keep,
    Object? systemPrinterName = _keep,
    String? networkHost,
    int? networkPort,
    int? paperWidthMm,
    bool? autoPrint,
    bool? showReceiptOnScreen,
    bool? openDrawerOnSale,
    int? drawerPin,
    bool? scannerEnabled,
    bool? scannerAutoAdd,
    int? scannerMinLength,
    bool? scannerFocusOnOpen,
  }) {
    return HardwareSettings(
      printerConnection: printerConnection ?? this.printerConnection,
      systemPrinterUrl: identical(systemPrinterUrl, _keep)
          ? this.systemPrinterUrl
          : systemPrinterUrl as String?,
      systemPrinterName: identical(systemPrinterName, _keep)
          ? this.systemPrinterName
          : systemPrinterName as String?,
      networkHost: networkHost ?? this.networkHost,
      networkPort: networkPort ?? this.networkPort,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      autoPrint: autoPrint ?? this.autoPrint,
      showReceiptOnScreen: showReceiptOnScreen ?? this.showReceiptOnScreen,
      openDrawerOnSale: openDrawerOnSale ?? this.openDrawerOnSale,
      drawerPin: drawerPin ?? this.drawerPin,
      scannerEnabled: scannerEnabled ?? this.scannerEnabled,
      scannerAutoAdd: scannerAutoAdd ?? this.scannerAutoAdd,
      scannerMinLength: scannerMinLength ?? this.scannerMinLength,
      scannerFocusOnOpen: scannerFocusOnOpen ?? this.scannerFocusOnOpen,
    );
  }

  static const Object _keep = Object();

  static const _p = 'hw_';

  static Future<HardwareSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final conn = prefs.getString('${_p}printer_connection');
    return HardwareSettings(
      printerConnection: PrinterConnection.values.firstWhere(
        (e) => e.name == conn,
        orElse: () => PrinterConnection.none,
      ),
      systemPrinterUrl: prefs.getString('${_p}system_printer_url'),
      systemPrinterName: prefs.getString('${_p}system_printer_name'),
      networkHost: prefs.getString('${_p}network_host') ?? '',
      networkPort: prefs.getInt('${_p}network_port') ?? 9100,
      paperWidthMm: prefs.getInt('${_p}paper_width') ?? 80,
      autoPrint: prefs.getBool('${_p}auto_print') ?? false,
      showReceiptOnScreen: prefs.getBool('${_p}show_receipt') ?? true,
      openDrawerOnSale: prefs.getBool('${_p}drawer_on_sale') ?? false,
      drawerPin: prefs.getInt('${_p}drawer_pin') ?? 0,
      scannerEnabled: prefs.getBool('${_p}scanner_enabled') ?? true,
      scannerAutoAdd: prefs.getBool('${_p}scanner_auto_add') ?? true,
      scannerMinLength: prefs.getInt('${_p}scanner_min_length') ?? 4,
      scannerFocusOnOpen: prefs.getBool('${_p}scanner_focus') ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_p}printer_connection', printerConnection.name);
    if (systemPrinterUrl == null) {
      await prefs.remove('${_p}system_printer_url');
    } else {
      await prefs.setString('${_p}system_printer_url', systemPrinterUrl!);
    }
    if (systemPrinterName == null) {
      await prefs.remove('${_p}system_printer_name');
    } else {
      await prefs.setString('${_p}system_printer_name', systemPrinterName!);
    }
    await prefs.setString('${_p}network_host', networkHost);
    await prefs.setInt('${_p}network_port', networkPort);
    await prefs.setInt('${_p}paper_width', paperWidthMm);
    await prefs.setBool('${_p}auto_print', autoPrint);
    await prefs.setBool('${_p}show_receipt', showReceiptOnScreen);
    await prefs.setBool('${_p}drawer_on_sale', openDrawerOnSale);
    await prefs.setInt('${_p}drawer_pin', drawerPin);
    await prefs.setBool('${_p}scanner_enabled', scannerEnabled);
    await prefs.setBool('${_p}scanner_auto_add', scannerAutoAdd);
    await prefs.setInt('${_p}scanner_min_length', scannerMinLength);
    await prefs.setBool('${_p}scanner_focus', scannerFocusOnOpen);
  }
}
