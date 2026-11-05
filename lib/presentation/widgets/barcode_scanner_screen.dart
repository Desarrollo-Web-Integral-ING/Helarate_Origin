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
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
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
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindow,
            errorBuilder: (context, error) {
              return Container(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.redAccent,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Permiso de Cámara Requerido',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Para escanear códigos de barras, autoriza el acceso a la cámara en los ajustes del dispositivo.\n\nDetalle: ${error.errorCode.name}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Volver'),
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

          // 2. Overlay sombreado y esquinas
          CustomPaint(
            painter: ScannerOverlayPainter(
              scanWindow: scanWindow,
              borderRadius: 16.0,
            ),
            child: const SizedBox.expand(),
          ),

          // 3. Línea láser animada
          AnimatedBuilder(
            animation: _laserPosition,
            builder: (context, child) {
              final topPos =
                  scanWindow.top + (scanWindow.height * _laserPosition.value);
              return Positioned(
                top: topPos,
                left: scanWindow.left + 10,
                width: scanWindow.width - 20,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 4. Instrucción en pantalla
          Positioned(
            top: scanWindow.bottom + 24,
            left: 20,
            right: 20,
            child: const Column(
              children: [
                Text(
                  'Apunta al código de barras o QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'El código se agregará automáticamente al carrito',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // 5. Barra superior con Controles (Volver, Linterna, Girar)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ),
                  Row(
                    children: [
                      // Botón Linterna
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
