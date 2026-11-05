// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class PlatformAvatarImage extends StatelessWidget {
  final String url;
  final double size;
  final String fallbackInitial;
  final Color backgroundColor;

  const PlatformAvatarImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallbackInitial,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _buildFallback();
    }

    // Registramos un elemento <img> HTML estándar nativo en el navegador.
    // Los tags <img> nativos del navegador NO están sujetos a las restricciones
    // CORS estrictas que CanvasKit de Flutter Web impone al hacer peticiones XHR/Fetch de bytes.
    final String viewType = 'avatar-native-${url.hashCode}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '50%'
          ..style.objectFit = 'cover';
        return img;
      },
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: HtmlElementView(viewType: viewType),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          fallbackInitial.isNotEmpty ? fallbackInitial[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
