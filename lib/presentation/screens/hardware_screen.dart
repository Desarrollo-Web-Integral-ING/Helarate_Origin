import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/hardware/hardware_service.dart';
import '../../core/hardware/hardware_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_toast.dart';

/// Configuración de los equipos de ESTA terminal: impresora de tickets,
/// cajón de dinero (conectado a la impresora) y lector de códigos.
class HardwareScreen extends StatefulWidget {
  const HardwareScreen({super.key});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> {
  final HardwareService hw = getIt<HardwareService>();
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  final _testCtrl = TextEditingController();
  final _testFocus = FocusNode();

  DateTime? _firstChar;
  String? _lastCode;
  int? _lastMs;
  bool _lastLooksScanner = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: hw.settings.networkHost);
    _portCtrl = TextEditingController(text: hw.settings.networkPort.toString());
    hw.refreshStatus();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _testCtrl.dispose();
    _testFocus.dispose();
    super.dispose();
  }

  HardwareSettings get s => hw.settings;

  void _report(HardwareResult r) {
    if (!mounted) return;
    if (r.ok) {
      AppToast.showSuccess(context, r.message);
    } else {
      AppToast.showError(context, r.message, title: 'Equipo no disponible');
    }
  }

  Future<void> _saveNetwork() async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    await hw.update(s.copyWith(
      networkHost: _hostCtrl.text.trim(),
      networkPort: port,
    ));
    if (!mounted) return;
    if (hw.status == PrinterStatus.ready) {
      AppToast.showSuccess(context, hw.statusDetail, title: 'Impresora conectada');
    } else {
      AppToast.showWarning(context, hw.statusDetail, title: 'No se pudo conectar');
    }
  }

  void _onTestChanged(String v) {
    if (v.length == 1 || _firstChar == null) _firstChar = DateTime.now();
    if (v.isEmpty) _firstChar = null;
  }

  void _onTestSubmit(String v) {
    final code = v.trim();
    if (code.isEmpty) return;
    final ms = _firstChar == null
        ? 0
        : DateTime.now().difference(_firstChar!).inMilliseconds;
    final perChar = code.isEmpty ? 0 : ms / code.length;
    setState(() {
      _lastCode = code;
      _lastMs = ms;
      // Un lector escribe todo el código en milisegundos; una persona no.
      _lastLooksScanner = code.length >= 3 && perChar <= 45;
    });
    _testCtrl.clear();
    _firstChar = null;
    _testFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipos de caja')),
      body: ListenableBuilder(
        listenable: hw,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
                  child: Text(
                    'Esta configuración es de esta terminal (computadora o tablet). '
                    'Cada caja puede tener su propia impresora, cajón y lector.',
                    style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                  ),
                ),
                _printerSection(context),
                const SizedBox(height: 16),
                _drawerSection(context),
                const SizedBox(height: 16),
                _scannerSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Impresora
  // ------------------------------------------------------------------

  Widget _printerSection(BuildContext context) {
    return _Section(
      icon: Icons.print_rounded,
      title: 'Impresora de tickets',
      subtitle: 'Solo se imprime si hay una impresora conectada. Si no, el ticket se ve en pantalla.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBanner(
            status: hw.status,
            detail: hw.statusDetail,
            checking: hw.checking,
            onRefresh: hw.refreshStatus,
          ),
          const SizedBox(height: 14),
          SegmentedButton<PrinterConnection>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                value: PrinterConnection.none,
                icon: Icon(Icons.print_disabled_rounded),
                label: Text('Ninguna'),
              ),
              const ButtonSegment(
                value: PrinterConnection.system,
                icon: Icon(Icons.usb_rounded),
                label: Text('Del sistema'),
              ),
              ButtonSegment(
                value: PrinterConnection.network,
                icon: const Icon(Icons.lan_rounded),
                label: const Text('Red (IP)'),
                enabled: HardwareService.supportsNetwork,
              ),
            ],
            selected: {s.printerConnection},
            onSelectionChanged: (v) => hw.update(s.copyWith(printerConnection: v.first)),
          ),
          const SizedBox(height: 14),
          if (s.printerConnection == PrinterConnection.system) _systemFields(context),
          if (s.printerConnection == PrinterConnection.network) _networkFields(context),
          if (s.printerConnection != PrinterConnection.none) ...[
            const SizedBox(height: 14),
            Text('Ancho del papel', style: TextStyle(fontWeight: FontWeight.w600, color: context.textMain)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 58, label: Text('58 mm')),
                ButtonSegment(value: 80, label: Text('80 mm')),
              ],
              selected: {s.paperWidthMm},
              onSelectionChanged: (v) => hw.update(s.copyWith(paperWidthMm: v.first)),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Imprimir automáticamente al cobrar'),
              subtitle: Text(
                hw.canAutoPrint
                    ? 'Cada venta guardada se imprime sin preguntar.'
                    : 'Requiere una impresora detectada. Mientras tanto, usa el botón Imprimir del ticket.',
                style: const TextStyle(fontSize: 12),
              ),
              value: s.autoPrint,
              onChanged: (v) => hw.update(s.copyWith(autoPrint: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar el ticket en pantalla'),
              subtitle: const Text('Útil para entregar el comprobante o copiarlo.',
                  style: TextStyle(fontSize: 12)),
              value: s.showReceiptOnScreen,
              onChanged: (v) => hw.update(s.copyWith(showReceiptOnScreen: v)),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: (!hw.canPrintManually || _busy)
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        final r = await hw.testPrint();
                        if (mounted) setState(() => _busy = false);
                        _report(r);
                      },
                icon: _busy
                    ? const AppSpinner(size: 16)
                    : const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Imprimir página de prueba'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _systemFields(BuildContext context) {
    if (!HardwareService.supportsSystemList) {
      return _Hint(
        icon: Icons.info_outline_rounded,
        text: 'En este dispositivo se usa el diálogo de impresión del sistema '
            '(no se puede listar impresoras). El ticket se imprime al pulsar '
            'Imprimir, y la impresión automática no está disponible.',
      );
    }
    final printers = hw.systemPrinters;
    final selected = printers.any((p) => p.url == s.systemPrinterUrl) ? s.systemPrinterUrl : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Impresora instalada',
              prefixIcon: Icon(Icons.print_rounded),
            ),
            items: [
              for (final p in printers)
                DropdownMenuItem(
                  value: p.url,
                  child: Text(
                    p.isAvailable ? p.name : '${p.name} (sin conexión)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            hint: Text(printers.isEmpty ? 'No se encontraron impresoras' : 'Elige una'),
            onChanged: (url) {
              final p = printers.firstWhere((e) => e.url == url);
              hw.update(s.copyWith(systemPrinterUrl: p.url, systemPrinterName: p.name));
            },
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: IconButton.filledTonal(
            tooltip: 'Buscar impresoras',
            onPressed: hw.refreshStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
    );
  }

  Widget _networkFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _hostCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Dirección IP',
                  hintText: '192.168.1.50',
                  prefixIcon: Icon(Icons.lan_rounded),
                ),
                onSubmitted: (_) => _saveNetwork(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _portCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Puerto'),
                onSubmitted: (_) => _saveNetwork(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _saveNetwork,
          icon: const Icon(Icons.link_rounded, size: 18),
          label: const Text('Guardar y verificar conexión'),
        ),
        const SizedBox(height: 8),
        _Hint(
          icon: Icons.info_outline_rounded,
          text: 'Para impresoras térmicas ESC/POS con red (Ethernet/Wi-Fi). '
              'El puerto habitual es 9100. La IP aparece en el ticket de '
              'autodiagnóstico de la impresora.',
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Cajón
  // ------------------------------------------------------------------

  Widget _drawerSection(BuildContext context) {
    final supported = hw.drawerSupported;
    return _Section(
      icon: Icons.point_of_sale_rounded,
      title: 'Cajón de dinero',
      subtitle: 'El cajón se conecta a la impresora de tickets (puerto RJ11) y se abre con un pulso que envía la impresora.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!supported)
            _Hint(
              icon: Icons.info_outline_rounded,
              text: s.printerConnection == PrinterConnection.system
                  ? 'Con una impresora "del sistema" el pulso no se puede enviar desde la app. '
                      'Activa "Abrir cajón" en las preferencias del driver de la impresora, '
                      'o usa conexión por Red (IP).'
                  : 'Configura primero una impresora por Red (IP) para controlar el cajón desde la app.',
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Abrir el cajón al cobrar'),
            subtitle: const Text('Se abre cada vez que una venta queda guardada.',
                style: TextStyle(fontSize: 12)),
            value: s.openDrawerOnSale && supported,
            onChanged: supported ? (v) => hw.update(s.copyWith(openDrawerOnSale: v)) : null,
          ),
          if (supported) ...[
            const SizedBox(height: 4),
            Text('Conector del cajón', style: TextStyle(fontWeight: FontWeight.w600, color: context.textMain)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Pin 2 (habitual)')),
                ButtonSegment(value: 1, label: Text('Pin 5')),
              ],
              selected: {s.drawerPin},
              onSelectionChanged: (v) => hw.update(s.copyWith(drawerPin: v.first)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: hw.status == PrinterStatus.ready
                  ? () async => _report(await hw.openDrawer())
                  : null,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Abrir cajón ahora (prueba)'),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Lector
  // ------------------------------------------------------------------

  Widget _scannerSection(BuildContext context) {
    return _Section(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Lector de código de barras / QR',
      subtitle: 'Los lectores USB o Bluetooth funcionan como un teclado: no necesitan instalación. Solo conéctalo y prueba abajo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar lector en Ventas'),
            value: s.scannerEnabled,
            onChanged: (v) => hw.update(s.copyWith(scannerEnabled: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Agregar al carrito al escanear'),
            subtitle: const Text('Si lo apagas, el código solo filtra la lista de productos.',
                style: TextStyle(fontSize: 12)),
            value: s.scannerAutoAdd,
            onChanged: s.scannerEnabled ? (v) => hw.update(s.copyWith(scannerAutoAdd: v)) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mantener el cursor en el campo de escaneo'),
            subtitle: const Text('Al abrir Ventas, el lector queda listo sin tocar la pantalla.',
                style: TextStyle(fontSize: 12)),
            value: s.scannerFocusOnOpen,
            onChanged: s.scannerEnabled ? (v) => hw.update(s.copyWith(scannerFocusOnOpen: v)) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cámara en modo continuo'),
            subtitle: const Text(
                'La cámara sigue abierta y va agregando cada producto que escaneas, mostrando la lista.',
                style: TextStyle(fontSize: 12)),
            value: s.scannerContinuous,
            onChanged: s.scannerEnabled ? (v) => hw.update(s.copyWith(scannerContinuous: v)) : null,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Largo mínimo del código: ${s.scannerMinLength}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.textMain),
                ),
              ),
              IconButton(
                onPressed: s.scannerMinLength > 1
                    ? () => hw.update(s.copyWith(scannerMinLength: s.scannerMinLength - 1))
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                onPressed: s.scannerMinLength < 20
                    ? () => hw.update(s.copyWith(scannerMinLength: s.scannerMinLength + 1))
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          Text(
            'Evita agregar productos por teclazos sueltos: se ignoran códigos más cortos.',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _testCtrl,
            focusNode: _testFocus,
            onChanged: _onTestChanged,
            onSubmitted: _onTestSubmit,
            decoration: const InputDecoration(
              labelText: 'Probar lector',
              hintText: 'Haz clic aquí y escanea un código',
              prefixIcon: Icon(Icons.qr_code_2_rounded),
            ),
          ),
          if (_lastCode != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_lastLooksScanner ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_lastLooksScanner ? Colors.green : Colors.orange).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastLooksScanner ? Icons.check_circle_rounded : Icons.keyboard_rounded,
                    color: _lastLooksScanner ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastLooksScanner
                              ? 'Lector detectado'
                              : 'Parece escritura manual',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Código: $_lastCode · ${_lastCode!.length} caracteres · $_lastMs ms',
                          style: TextStyle(fontSize: 12, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Widgets de apoyo
// ======================================================================

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 12.5, color: context.textMuted, height: 1.4)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.textMuted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: context.textMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final PrinterStatus status;
  final String detail;
  final bool checking;
  final Future<void> Function() onRefresh;

  const _StatusBanner({
    required this.status,
    required this.detail,
    required this.checking,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String label;
    switch (status) {
      case PrinterStatus.ready:
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        label = 'Conectada';
        break;
      case PrinterStatus.unverified:
        color = Colors.blue;
        icon = Icons.info_rounded;
        label = 'Manual';
        break;
      case PrinterStatus.offline:
        color = Colors.red;
        icon = Icons.error_rounded;
        label = 'Sin conexión';
        break;
      case PrinterStatus.notConfigured:
        color = Colors.grey;
        icon = Icons.print_disabled_rounded;
        label = 'Sin impresora';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          checking ? AppSpinner(size: 22, color: color) : Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                Text(detail, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
          if (status != PrinterStatus.notConfigured)
            TextButton(
              onPressed: checking ? null : onRefresh,
              child: const Text('Verificar'),
            ),
        ],
      ),
    );
  }
}
