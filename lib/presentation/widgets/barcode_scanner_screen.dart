import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/di/service_locator.dart';
import '../../core/hardware/hardware_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/camera_access_api.dart';

/// Resultado de procesar un código leído en modo "caja" (continuo).
class ScanOutcome {
  final bool found;
  final String title; // nombre del producto, o el código si no existe
  final int quantity; // cantidad actual en la caja
  final String? subtitle;

  const ScanOutcome({
    required this.found,
    required this.title,
    this.quantity = 0,
    this.subtitle,
  });
}

class _ScanEntry {
  final String code;
  ScanOutcome outcome;
  int times;
  _ScanEntry(this.code, this.outcome) : times = 1;
}

/// Escáner con la cámara del dispositivo (códigos de barras y QR).
///
/// Dos formas de uso:
///  - Simple (formularios): se lee UN código, la pantalla se cierra sola y
///    devuelve el valor con Navigator.pop. Quien la abre NO debe hacer pop.
///  - Caja ([onCode]): cada código se procesa al instante (p. ej. se agrega al
///    carrito) y, con el modo continuo activo, la cámara sigue abierta mostrando
///    lo que se va agregando.
///
/// Pide el permiso de cámara de forma explícita en Android/iOS. En el
/// navegador el aviso de permiso lo muestra el propio navegador al abrir la
/// cámara (requiere HTTPS o localhost).
class BarcodeScannerScreen extends StatefulWidget {
  /// Opcional. Se llama una vez al leer el código (modo simple).
  final void Function(String code)? onScanned;

  /// Modo caja: procesa cada código y devuelve qué pasó para mostrarlo.
  final ScanOutcome Function(String code)? onCode;

  const BarcodeScannerScreen({super.key, this.onScanned, this.onCode});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}
enum _CamState {
  checking,
  ready,
  denied,
  permanentlyDenied,
  insecure,
  browserDenied,
  noCamera,
  inUse,
  policy,
  failed,
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animCtrl;
  late final Animation<double> _laserPosition;
  bool _hasScanned = false;
  _CamState _camState = _CamState.checking;
  late bool _continuous;
  final List<_ScanEntry> _session = [];
  final Map<String, DateTime> _lastSeen = {};
  String? _flashText;
  bool _flashOk = true;
  int _flashToken = 0;
  String? _detail; // texto técnico del último fallo (para diagnóstico)

  bool get _isMobileOs =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // El controlador se inicia solo al montarse MobileScanner, y ese widget
    // únicamente se construye cuando el permiso ya está concedido.
    _continuous = widget.onCode != null &&
        getIt<HardwareService>().settings.scannerContinuous;
    _controller = MobileScannerController(
      // Los duplicados se filtran aquí (por tiempo) para poder sumar el mismo
      // producto escaneándolo varias veces.
      detectionSpeed: DetectionSpeed.normal,
      // En laptops/PC no existe cámara trasera; solo se pide en móviles.
      facing: _isMobileOs ? CameraFacing.back : CameraFacing.front,
      torchEnabled: false,
    );

    _animCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _laserPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    _prepareCamera();
  }

  Future<void> _prepareCamera() async {
    setState(() {
      _camState = _CamState.checking;
      _detail = null;
    });

    if (kIsWeb) {
      // Pedimos la cámara nosotros mismos: así el navegador muestra su aviso
      // de permiso y, si falla, sabemos exactamente por qué.
      final r = await requestBrowserCamera();
      if (!mounted) return;
      if (!r.ok) {
        setState(() {
          _detail = r.detail;
          _camState = switch (r.access) {
            CameraAccess.denied => _CamState.browserDenied,
            CameraAccess.noDevice => _CamState.noCamera,
            CameraAccess.inUse => _CamState.inUse,
            CameraAccess.blockedByPolicy => _CamState.policy,
            CameraAccess.insecure => _CamState.insecure,
            _ => _CamState.failed,
          };
        });
        return;
      }
    } else if (_isMobileOs) {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isPermanentlyDenied || status.isRestricted) {
        setState(() => _camState = _CamState.permanentlyDenied);
        return;
      }
      if (!status.isGranted && !status.isLimited) {
        setState(() => _camState = _CamState.denied);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _camState = _CamState.ready);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _handleCode(value);
      break;
    }
  }

  void _handleCode(String code) {
    if (_hasScanned) return;
    if (widget.onCode == null) {
      _finish(code);
      return;
    }
    if (!_continuous) {
      // Modo caja sin continuo: se procesa un código y se cierra.
      _hasScanned = true;
      final outcome = widget.onCode!(code);
      HapticFeedback.mediumImpact();
      widget.onScanned?.call(code);
      // Devuelve el código solo si NO se encontró (para dejarlo en el buscador).
      Navigator.of(context).pop(outcome.found ? null : code);
      return;
    }
    // Continuo: ignora la misma lectura repetida en menos de 1.5 s.
    final now = DateTime.now();
    final last = _lastSeen[code];
    if (last != null && now.difference(last) < const Duration(milliseconds: 1500)) {
      _lastSeen[code] = now;
      return;
    }
    _lastSeen[code] = now;

    final outcome = widget.onCode!(code);
    outcome.found ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    if (!mounted) return;
    setState(() {
      final idx = _session.indexWhere((e) => e.code == code);
      if (idx >= 0) {
        final e = _session.removeAt(idx);
        e.outcome = outcome;
        e.times++;
        _session.insert(0, e);
      } else {
        _session.insert(0, _ScanEntry(code, outcome));
      }
    });
    _flash(outcome.found ? ' · x' : 'No encontrado: ', outcome.found);
  }

  void _flash(String text, bool ok) {
    final token = ++_flashToken;
    setState(() {
      _flashText = text;
      _flashOk = ok;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && token == _flashToken) setState(() => _flashText = null);
    });
  }

  Future<void> _toggleContinuous() async {
    final hw = getIt<HardwareService>();
    final next = !_continuous;
    setState(() => _continuous = next);
    await hw.update(hw.settings.copyWith(scannerContinuous: next));
  }

  /// Entrega el código y cierra SOLO el escáner (un único pop).
  void _finish(String code) {
    if (_hasScanned || !mounted) return;
    _hasScanned = true;
    widget.onScanned?.call(code);
    Navigator.of(context).pop(code);
  }

  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escribir código'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Código de barras / QR',
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Usar código'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (code == null || code.isEmpty) return;
    if (widget.onCode != null && _continuous) {
      _lastSeen.remove(code);
      _handleCode(code);
    } else {
      _handleCode(code);
    }
  }

  /// Panel de problema con instrucciones claras y acciones.
  Widget _problemPanel({
    required IconData icon,
    required String title,
    required String message,
    String? primaryLabel,
    IconData primaryIcon = Icons.refresh_rounded,
    VoidCallback? onPrimary,
    String? detail,
  }) {
    return Container(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.amberAccent, size: 64),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SelectableText(
                    'Detalle técnico: $detail',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                  ),
                ],
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (primaryLabel != null)
                      ElevatedButton.icon(
                        onPressed: onPrimary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(primaryIcon),
                        label: Text(primaryLabel),
                      ),
                    OutlinedButton.icon(
                      onPressed: _manualEntry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Escribir código'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return _problemPanel(
          icon: Icons.no_photography_outlined,
          title: 'Permiso de cámara denegado',
          message: kIsWeb
              ? 'Bloqueaste la cámara para este sitio. Pulsa el candado junto a la dirección del navegador, '
                  'cambia "Cámara" a "Permitir" y pulsa Reintentar.'
              : 'Activa el permiso de cámara en los ajustes del dispositivo y vuelve a intentarlo.',
          primaryLabel: kIsWeb ? 'Reintentar' : 'Abrir ajustes',
          primaryIcon: kIsWeb ? Icons.refresh_rounded : Icons.settings_rounded,
          onPrimary: kIsWeb ? _prepareCamera : openAppSettings,
        );
      case MobileScannerErrorCode.unsupported:
        return _problemPanel(
          icon: Icons.videocam_off_outlined,
          title: 'Cámara no compatible',
          message: 'Este navegador o dispositivo no permite usar la cámara para escanear. '
              'Puedes usar un lector USB/Bluetooth o escribir el código.',
        );
      default:
        final detail = error.errorDetails?.message;
        return _problemPanel(
          icon: Icons.camera_alt_outlined,
          title: 'No se pudo iniciar la cámara',
          message: 'Comprueba que ninguna otra aplicación esté usando la cámara y que esté conectada.'
              '${detail != null ? '\n\n($detail)' : ''}',
          primaryLabel: 'Reintentar',
          onPrimary: _prepareCamera,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_camState) {
      case _CamState.checking:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      case _CamState.denied:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.no_photography_outlined,
            title: 'Necesitamos la cámara',
            message: 'Para escanear códigos con la cámara hay que permitir su uso. '
                'Pulsa el botón y acepta el aviso del sistema.',
            primaryLabel: 'Permitir cámara',
            primaryIcon: Icons.camera_alt_rounded,
            onPrimary: _prepareCamera,
          ),
        );
      case _CamState.permanentlyDenied:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.no_photography_outlined,
            title: 'Permiso de cámara bloqueado',
            message: 'El sistema ya no volverá a preguntar. Abre los ajustes de la app, '
                'entra en Permisos y activa Cámara.',
            primaryLabel: 'Abrir ajustes',
            primaryIcon: Icons.settings_rounded,
            onPrimary: () async {
              await openAppSettings();
            },
          ),
        );
      case _CamState.insecure:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.lock_outline_rounded,
            title: 'La cámara requiere HTTPS',
            message: 'Los navegadores solo permiten la cámara en páginas seguras (https://) '
                'o en localhost. Abre la app con HTTPS, o usa un lector USB/Bluetooth.',
            detail: _detail,
          ),
        );
      case _CamState.browserDenied:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.no_photography_outlined,
            title: 'El navegador no dio acceso a la cámara',
            message: 'Si no te apareció ningún aviso, el permiso está bloqueado para este sitio:\n\n'
                '1. Pulsa el icono de candado (o de cámara tachada) junto a la dirección.\n'
                '2. Cambia "Cámara" a "Permitir".\n'
                '3. Pulsa Reintentar.\n\n'
                'Si abriste la app dentro de un navegador integrado de un editor (vista previa), '
                'esos no muestran permisos: ábrela en Chrome o Edge. '
                'También revisa Windows: Configuración > Privacidad > Cámara > permitir apps de escritorio.',
            primaryLabel: 'Reintentar',
            onPrimary: _prepareCamera,
            detail: _detail,
          ),
        );
      case _CamState.noCamera:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.videocam_off_outlined,
            title: 'No se detecta ninguna cámara',
            message: 'Este equipo no tiene una cámara conectada o está deshabilitada, '
                'por eso el navegador ni siquiera muestra el aviso de permiso. '
                'Conecta una cámara web, abre la app desde un celular, '
                'o usa un lector USB/Bluetooth o escribe el código.',
            primaryLabel: 'Reintentar',
            onPrimary: _prepareCamera,
            detail: _detail,
          ),
        );
      case _CamState.inUse:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.videocam_outlined,
            title: 'La cámara está en uso',
            message: 'Otra aplicación o pestaña (Zoom, Teams, otra pestaña del navegador) '
                'está usando la cámara. Ciérrala y pulsa Reintentar.',
            primaryLabel: 'Reintentar',
            onPrimary: _prepareCamera,
            detail: _detail,
          ),
        );
      case _CamState.policy:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.policy_outlined,
            title: 'La configuración del sitio bloquea la cámara',
            message: 'El servidor de esta página envía una regla (Permissions-Policy) que prohíbe usar la cámara, '
                'por eso el navegador no muestra el aviso de permiso. '
                'Hay que permitir camera=(self) en la cabecera del sitio y volver a publicar. '
                'Mientras tanto puedes escribir el código o usar un lector USB/Bluetooth.',
            detail: _detail,
          ),
        );
      case _CamState.failed:
        return Scaffold(
          backgroundColor: Colors.black,
          body: _problemPanel(
            icon: Icons.camera_alt_outlined,
            title: 'No se pudo abrir la cámara',
            message: 'Ocurrió un error inesperado al pedir la cámara al navegador.',
            primaryLabel: 'Reintentar',
            onPrimary: _prepareCamera,
            detail: _detail,
          ),
        );
      case _CamState.ready:
        return _buildScanner(context);
    }
  }

  Widget _buildScanner(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowWidth = (size.width * 0.78).clamp(220.0, 520.0);
    const scanWindowHeight = 180.0;
    final showPanel = widget.onCode != null && _continuous;
    final panelH = showPanel ? (size.height * 0.40).clamp(190.0, 330.0) : 0.0;
    final windowTop = ((size.height - panelH - scanWindowHeight) / 2 - 10).clamp(78.0, double.infinity);
    final scanWindow = Rect.fromLTWH(
      (size.width - scanWindowWidth) / 2,
      windowTop,
      scanWindowWidth,
      scanWindowHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Escáner de cámara
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindow,
            errorBuilder: (context, error) => _buildCameraError(error),
            onDetect: _onDetect,
          ),

          // 2. Overlay oscuro con ventana recortada
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: ScannerOverlayPainter(scanWindow: scanWindow),
            ),
          ),

          // 3. Línea láser animada
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _laserPosition,
              builder: (context, child) {
                final topPos =
                    scanWindow.top + (scanWindow.height * _laserPosition.value);
                return Stack(
                  children: [
                    Positioned(
                      left: scanWindow.left + 8,
                      top: topPos,
                      width: scanWindow.width - 16,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 4. Barra superior flotante
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      if (widget.onCode != null) ...[
                        FilterChip(
                          selected: _continuous,
                          onSelected: (_) => _toggleContinuous(),
                          avatar: Icon(Icons.playlist_add_check_rounded,
                              size: 18, color: _continuous ? Colors.white : Colors.white70),
                          label: const Text('Continuo'),
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          selectedColor: AppTheme.brandPrimary,
                          showCheckmark: false,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        const SizedBox(width: 10),
                      ],
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Escribir código',
                        icon: const Icon(Icons.keyboard_rounded),
                        onPressed: _manualEntry,
                      ),
                      const SizedBox(width: 10),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          final isFlashOn = state.torchState == TorchState.on;
                          return IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                            ),
                            icon: Icon(
                              isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: isFlashOn ? Colors.yellow : Colors.white,
                            ),
                            onPressed: () => _controller.toggleTorch(),
                            tooltip: 'Linterna',
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.flip_camera_android_rounded),
                        onPressed: () => _controller.switchCamera(),
                        tooltip: 'Girar cámara',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Aviso breve de lo que se acaba de escanear
          if (_flashText != null)
            Positioned(
              left: 24,
              right: 24,
              top: scanWindow.bottom + 14,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: (_flashOk ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_flashOk ? Icons.check_circle_rounded : Icons.error_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _flashText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 6. Lista de lo que se va agregando (modo continuo)
          if (showPanel) _buildSessionPanel(panelH),
        ],
      ),
    );
  }

  Widget _buildSessionPanel(double height) {
    final found = _session.where((e) => e.outcome.found).toList();
    final piezas = found.fold<int>(0, (s, e) => s + e.outcome.quantity);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                child: Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        found.isEmpty
                            ? 'Escanea productos: se agregan solos'
                            : 'En caja · ${found.length} productos · $piezas pzs',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Listo'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _session.isEmpty
                    ? const Center(
                        child: Text(
                          'Apunta la cámara al código de barras o QR',
                          style: TextStyle(color: Colors.white38, fontSize: 12.5),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        itemCount: _session.length,
                        itemBuilder: (_, i) {
                          final e = _session[i];
                          final o = e.outcome;
                          final latest = i == 0;
                          final color = o.found ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: latest
                                  ? color.withValues(alpha: 0.16)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: latest ? color.withValues(alpha: 0.6) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(o.found ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                    color: color, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.found ? o.title : 'Código no encontrado',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: latest ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: latest ? 14.5 : 13,
                                        ),
                                      ),
                                      Text(
                                        o.found ? (o.subtitle ?? e.code) : e.code,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                if (o.found)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'x${o.quantity}',
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w900,
                                          fontSize: latest ? 17 : 14),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter({required this.scanWindow, this.borderRadius = 16.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanWindowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanWindowPath,
    );

    canvas.drawPath(overlayPath, paint);

    final borderPaint = Paint()
      ..color = AppTheme.brandPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final path = Path();
    final r = borderRadius;
    const len = 20.0;

    // Esquina superior izquierda
    path.moveTo(scanWindow.left, scanWindow.top + len);
    path.lineTo(scanWindow.left, scanWindow.top + r);
    path.quadraticBezierTo(scanWindow.left, scanWindow.top, scanWindow.left + r, scanWindow.top);
    path.lineTo(scanWindow.left + len, scanWindow.top);

    // Esquina superior derecha
    path.moveTo(scanWindow.right - len, scanWindow.top);
    path.lineTo(scanWindow.right - r, scanWindow.top);
    path.quadraticBezierTo(scanWindow.right, scanWindow.top, scanWindow.right, scanWindow.top + r);
    path.lineTo(scanWindow.right, scanWindow.top + len);

    // Esquina inferior izquierda
    path.moveTo(scanWindow.left, scanWindow.bottom - len);
    path.lineTo(scanWindow.left, scanWindow.bottom - r);
    path.quadraticBezierTo(scanWindow.left, scanWindow.bottom, scanWindow.left + r, scanWindow.bottom);
    path.lineTo(scanWindow.left + len, scanWindow.bottom);

    // Esquina inferior derecha
    path.moveTo(scanWindow.right - len, scanWindow.bottom);
    path.lineTo(scanWindow.right - r, scanWindow.bottom);
    path.quadraticBezierTo(scanWindow.right, scanWindow.bottom, scanWindow.right, scanWindow.bottom - r);
    path.lineTo(scanWindow.right, scanWindow.bottom - len);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius;
  }
}
