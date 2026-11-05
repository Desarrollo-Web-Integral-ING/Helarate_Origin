import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Import condicional: En Web usa HtmlElementView nativo sin CORS CanvasKit
import 'avatar_image_stub.dart'
    if (dart.library.html) 'avatar_image_web.dart';

class AppAvatarImage extends StatelessWidget {
  final String url;
  final double size;
  final String fallbackInitial;
  final Color backgroundColor;

  const AppAvatarImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallbackInitial,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformAvatarImage(
      url: url,
      size: size,
      fallbackInitial: fallbackInitial,
      backgroundColor: backgroundColor,
    );
  }
}
