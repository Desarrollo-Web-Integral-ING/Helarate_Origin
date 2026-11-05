import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Loader de pantalla/sección: anillo degradado que gira alrededor de un
/// ícono que "respira". Usa el color de marca del tema.
class AppLoader extends StatefulWidget {
  final String? message;
  final IconData icon;
  final double size;

  const AppLoader({
    super.key,
    this.message,
    this.icon = Icons.storefront_rounded,
    this.size = 72,
  });

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final textColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final pulse =
                      0.85 + 0.15 * math.sin(_c.value * 2 * math.pi);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _c.value * 2 * math.pi,
                        child: CustomPaint(
                          size: Size.square(widget.size),
                          painter: _ArcPainter(color: color, stroke: 4),
                        ),
                      ),
                      Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: widget.size * 0.52,
                          height: widget.size * 0.52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.12),
                          ),
                          child: Icon(widget.icon,
                              color: color, size: widget.size * 0.30),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 18),
            Text(
              widget.message!,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spinner pequeño para botones y acciones inline.
class AppSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final double stroke;

  const AppSpinner({super.key, this.size = 20, this.color, this.stroke = 2.5});

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ArcPainter(color: color, stroke: widget.stroke),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double stroke;

  _ArcPainter({required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.12);
    canvas.drawArc(deflated, 0, 2 * math.pi, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.0), color],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(deflated, -math.pi / 2, math.pi * 1.5, false, arc);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.color != color || old.stroke != stroke;
}

/// Pantalla completa de arranque.
class AppSplash extends StatelessWidget {
  final String message;
  const AppSplash({super.key, this.message = 'Cargando tu negocio...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: AppLoader(message: message));
  }
}
