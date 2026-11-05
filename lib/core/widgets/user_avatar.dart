import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Estilo de avatar disponible para elegir en el perfil.
class AvatarStyle {
  final String id;
  final String label;
  const AvatarStyle(this.id, this.label);
}

/// Avatar generado en la propia app (sin internet ni servicios externos).
/// El mismo `style` + `seed` siempre produce el mismo dibujo.
class UserAvatar extends StatelessWidget {
  final String style;
  final String seed;
  final String name;
  final double size;
  final bool circle;

  const UserAvatar({
    super.key,
    required this.style,
    required this.seed,
    required this.name,
    this.size = 40,
    this.circle = true,
  });

  static const List<AvatarStyle> styles = [
    AvatarStyle('gradiente', 'Degradado'),
    AvatarStyle('iniciales', 'Iniciales'),
    AvatarStyle('geometrico', 'Geométrico'),
    AvatarStyle('pixel', 'Pixel'),
    AvatarStyle('burbujas', 'Burbujas'),
    AvatarStyle('robot', 'Robot'),
    AvatarStyle('cara', 'Personaje'),
  ];

  static const String defaultStyle = 'gradiente';

  /// Los estilos antiguos (p. ej. los de DiceBear guardados en la base de
  /// datos) se convierten en uno local de forma estable.
  static String resolveStyle(String? id, String seed) {
    for (final s in styles) {
      if (s.id == id) return s.id;
    }
    return styles[_hash('${id ?? ''}$seed') % styles.length].id;
  }

  static int _hash(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Semilla efectiva: la guardada o, si no hay, el nombre.
  static String effectiveSeed(String? seed, String name) =>
      (seed != null && seed.trim().isNotEmpty) ? seed.trim() : (name.isNotEmpty ? name : 'usuario');

  @override
  Widget build(BuildContext context) {
    final s = effectiveSeed(seed, name);
    final resolved = resolveStyle(style, s);
    final painter = _AvatarPainter(resolved, s, name);
    final child = RepaintBoundary(
      child: CustomPaint(size: Size.square(size), painter: painter),
    );
    return SizedBox(
      width: size,
      height: size,
      child: circle
          ? ClipOval(child: child)
          : ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: child),
    );
  }
}

class _Pal {
  final Color a;
  final Color b;
  final Color soft;
  final Color ink;
  const _Pal(this.a, this.b, this.soft, this.ink);
}

const List<_Pal> _palettes = [
  _Pal(Color(0xFF2563EB), Color(0xFF38BDF8), Color(0xFFDBEAFE), Color(0xFF1E3A8A)),
  _Pal(Color(0xFF10B981), Color(0xFF34D399), Color(0xFFD1FAE5), Color(0xFF065F46)),
  _Pal(Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFEF3C7), Color(0xFF78350F)),
  _Pal(Color(0xFFEC4899), Color(0xFFF472B6), Color(0xFFFCE7F3), Color(0xFF831843)),
  _Pal(Color(0xFF8B5CF6), Color(0xFFA78BFA), Color(0xFFEDE9FE), Color(0xFF4C1D95)),
  _Pal(Color(0xFFEF4444), Color(0xFFFB7185), Color(0xFFFEE2E2), Color(0xFF7F1D1D)),
  _Pal(Color(0xFF14B8A6), Color(0xFF2DD4BF), Color(0xFFCCFBF1), Color(0xFF134E4A)),
  _Pal(Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFFE0E7FF), Color(0xFF312E81)),
  _Pal(Color(0xFFF97316), Color(0xFFFB923C), Color(0xFFFFEDD5), Color(0xFF7C2D12)),
  _Pal(Color(0xFF0EA5E9), Color(0xFF22D3EE), Color(0xFFCFFAFE), Color(0xFF164E63)),
];

const List<Color> _skin = [
  Color(0xFFFFE0BD), Color(0xFFF5CBA7), Color(0xFFE0AC69), Color(0xFFC68642), Color(0xFF8D5524),
];

class _AvatarPainter extends CustomPainter {
  final String style;
  final String seed;
  final String name;

  _AvatarPainter(this.style, this.seed, this.name);

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  void _text(Canvas c, Size s, String t, Color color, {double scale = 0.38}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: color,
          fontSize: s.width * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((s.width - tp.width) / 2, (s.height - tp.height) / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = UserAvatar._hash(seed);
    final rnd = math.Random(h);
    final pal = _palettes[h % _palettes.length];
    final rect = Offset.zero & size;
    final w = size.width;

    switch (style) {
      case 'iniciales':
        canvas.drawRect(rect, Paint()..color = pal.soft);
        _text(canvas, size, _initials, pal.ink);
        break;

      case 'geometrico':
        canvas.drawRect(rect, Paint()..color = pal.a);
        for (var i = 0; i < 3; i++) {
          final p = Paint()..color = (i.isEven ? pal.b : Colors.white).withValues(alpha: 0.55);
          final cx = rnd.nextDouble() * w;
          final cy = rnd.nextDouble() * w;
          final r = w * (0.18 + rnd.nextDouble() * 0.25);
          if (i == 1) {
            canvas.save();
            canvas.translate(cx, cy);
            canvas.rotate(rnd.nextDouble() * math.pi);
            canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2), Radius.circular(r * 0.3)),
              p,
            );
            canvas.restore();
          } else {
            canvas.drawCircle(Offset(cx, cy), r, p);
          }
        }
        break;

      case 'pixel':
        canvas.drawRect(rect, Paint()..color = pal.soft);
        final cell = w / 6;
        final fill = Paint()..color = pal.a;
        for (var y = 0; y < 5; y++) {
          for (var x = 0; x < 3; x++) {
            if (rnd.nextBool()) {
              canvas.drawRect(Rect.fromLTWH(cell * (x + 0.5), cell * (y + 0.5), cell, cell), fill);
              canvas.drawRect(Rect.fromLTWH(cell * (4 - x + 0.5), cell * (y + 0.5), cell, cell), fill);
            }
          }
        }
        break;

      case 'burbujas':
        canvas.drawRect(
          rect,
          Paint()..shader = LinearGradient(colors: [pal.a, pal.b], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect),
        );
        for (var i = 0; i < 6; i++) {
          canvas.drawCircle(
            Offset(rnd.nextDouble() * w, rnd.nextDouble() * w),
            w * (0.06 + rnd.nextDouble() * 0.16),
            Paint()..color = Colors.white.withValues(alpha: 0.18 + rnd.nextDouble() * 0.25),
          );
        }
        break;

      case 'robot':
        canvas.drawRect(rect, Paint()..color = pal.soft);
        final head = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, w * 0.28, w * 0.6, w * 0.52),
          Radius.circular(w * 0.1),
        );
        // antena
        final ink = Paint()..color = pal.ink..strokeWidth = w * 0.035..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(w * 0.5, w * 0.28), Offset(w * 0.5, w * 0.16), ink);
        canvas.drawCircle(Offset(w * 0.5, w * 0.14), w * 0.04, Paint()..color = pal.b);
        // orejas
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, w * 0.46, w * 0.08, w * 0.16), Radius.circular(w * 0.02)), Paint()..color = pal.ink);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.8, w * 0.46, w * 0.08, w * 0.16), Radius.circular(w * 0.02)), Paint()..color = pal.ink);
        canvas.drawRRect(head, Paint()..color = pal.a);
        // ojos
        final eyeR = w * (0.07 + (h % 3) * 0.015);
        for (final dx in [0.36, 0.64]) {
          canvas.drawCircle(Offset(w * dx, w * 0.5), eyeR, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(w * dx, w * 0.5), eyeR * 0.5, Paint()..color = pal.ink);
        }
        // boca
        final mouth = Paint()..color = Colors.white..strokeWidth = w * 0.035..strokeCap = StrokeCap.round;
        final mv = (h >> 3) % 3;
        if (mv == 0) {
          canvas.drawLine(Offset(w * 0.38, w * 0.68), Offset(w * 0.62, w * 0.68), mouth);
        } else if (mv == 1) {
          for (var i = 0; i < 4; i++) {
            canvas.drawLine(Offset(w * (0.38 + i * 0.08), w * 0.65), Offset(w * (0.38 + i * 0.08), w * 0.71), mouth);
          }
        } else {
          canvas.drawArc(Rect.fromLTWH(w * 0.38, w * 0.6, w * 0.24, w * 0.12), 0, math.pi, false, mouth..style = PaintingStyle.stroke);
        }
        break;

      case 'cara':
        canvas.drawRect(rect, Paint()..color = pal.a);
        final skin = _skin[(h >> 2) % _skin.length];
        final hairColors = [const Color(0xFF2D1B0E), const Color(0xFF6B4423), const Color(0xFFB8860B), const Color(0xFF1F1F1F), const Color(0xFFC0392B)];
        final hair = hairColors[(h >> 5) % hairColors.length];
        // hombros
        canvas.drawOval(Rect.fromLTWH(w * 0.1, w * 0.72, w * 0.8, w * 0.6), Paint()..color = pal.ink);
        // cabello (atrás)
        canvas.drawCircle(Offset(w * 0.5, w * 0.42), w * 0.3, Paint()..color = hair);
        // cara
        canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, w * 0.48), width: w * 0.46, height: w * 0.52), Paint()..color = skin);
        // flequillo
        canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, w * 0.4), width: w * 0.5, height: w * 0.4), math.pi, math.pi, true, Paint()..color = hair);
        // ojos
        final eye = Paint()..color = const Color(0xFF1F1F1F);
        final ev = (h >> 7) % 2;
        for (final dx in [0.4, 0.6]) {
          if (ev == 0) {
            canvas.drawCircle(Offset(w * dx, w * 0.5), w * 0.027, eye);
          } else {
            canvas.drawOval(Rect.fromCenter(center: Offset(w * dx, w * 0.5), width: w * 0.05, height: w * 0.07), eye);
          }
        }
        // boca
        final mp = Paint()
          ..color = const Color(0xFF7A2E2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03
          ..strokeCap = StrokeCap.round;
        final mv2 = (h >> 9) % 3;
        if (mv2 == 0) {
          canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, w * 0.6), width: w * 0.2, height: w * 0.12), 0.2, math.pi - 0.4, false, mp);
        } else if (mv2 == 1) {
          canvas.drawLine(Offset(w * 0.44, w * 0.63), Offset(w * 0.56, w * 0.63), mp);
        } else {
          canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, w * 0.63), width: w * 0.1, height: w * 0.07), Paint()..color = const Color(0xFF7A2E2E));
        }
        break;

      case 'gradiente':
      default:
        canvas.drawRect(
          rect,
          Paint()..shader = LinearGradient(colors: [pal.a, pal.b], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect),
        );
        _text(canvas, size, _initials, Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.style != style || old.seed != seed || old.name != name;
}
