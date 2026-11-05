import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final void Function(String code) onScanned;

  const BarcodeScannerScreen({super.key, required this.onScanned});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animCtrl;
  late final Animation<double> _laserPosition;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    // En Web en laptops o desktops no existe CameraFacing.back y causa genericError.
    // Solo forzamos CameraFacing.back en plataformas móviles reales.
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: kIsWeb ? null : CameraFacing.back,
      torchEnabled: false,
    );

    _animCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _laserPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanWindowWidth = size.width * 0.78;
    const scanWindowHeight = 180.0;
    final scanWindow = Rect.fromLTWH(
      (size.width - scanWindowWidth) / 2,
      (size.height - scanWindowHeight) / 2 - 30,
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
            errorBuilder: (context, error) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.amberAccent,
                          size: 68,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Permiso de Cámara Requerido',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se pudo acceder a la cámara. Por favor autoriza el permiso en el navegador o ajustes de tu dispositivo.\n(${error.errorCode.name}${error.errorDetails?.message != null ? ': ' + error.errorDetails!.message! : ''})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _controller.start(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.brandPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancelar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            onDetect: (BarcodeCapture capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _hasScanned = true;
                  widget.onScanned(barcode.rawValue!);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),

          // 2. Overlay Oscuro con Ventana Recortada
          CustomPaint(
            size: size,
            painter: ScannerOverlayPainter(scanWindow: scanWindow),
          ),

          // 3. Línea Láser Animada
          AnimatedBuilder(
            animation: _laserPosition,
            builder: (context, child) {
              final topPos =
                  scanWindow.top + (scanWindow.height * _laserPosition.value);
              return Positioned(
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
              );
            },
          ),

          // 4. Barra Superior Flotante
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
                      // Botón Linterna (solo móvil habitualmente)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            final isFlashOn = state.torchState == TorchState.on;
                            return IconButton(
                              icon: Icon(
                                isFlashOn
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                color: isFlashOn ? Colors.yellow : Colors.white,
                              ),
                              onPressed: () => _controller.toggleTorch(),
                              tooltip: 'Linterna',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón Girar Cámara
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            return IconButton(
                              icon: const Icon(
                                Icons.flip_camera_android_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => _controller.switchCamera(),
                              tooltip: 'Girar Cámara',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
    path.quadraticBezierTo(
      scanWindow.left,
      scanWindow.top,
      scanWindow.left + r,
      scanWindow.top,
    );
    path.lineTo(scanWindow.left + len, scanWindow.top);

    // Esquina superior derecha
    path.moveTo(scanWindow.right - len, scanWindow.top);
    path.lineTo(scanWindow.right - r, scanWindow.top);
    path.quadraticBezierTo(
      scanWindow.right,
      scanWindow.top,
      scanWindow.right,
      scanWindow.top + r,
    );
    path.lineTo(scanWindow.right, scanWindow.top + len);

    // Esquina inferior izquierda
    path.moveTo(scanWindow.left, scanWindow.bottom - len);
    path.lineTo(scanWindow.left, scanWindow.bottom - r);
    path.quadraticBezierTo(
      scanWindow.left,
      scanWindow.bottom,
      scanWindow.left + r,
      scanWindow.bottom,
    );
    path.lineTo(scanWindow.left + len, scanWindow.bottom);

    // Esquina inferior derecha
    path.moveTo(scanWindow.right - len, scanWindow.bottom);
    path.lineTo(scanWindow.right - r, scanWindow.bottom);
    path.quadraticBezierTo(
      scanWindow.right,
      scanWindow.bottom,
      scanWindow.right,
      scanWindow.bottom - r,
    );
    path.lineTo(scanWindow.right, scanWindow.bottom - len);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius;
  }
}
