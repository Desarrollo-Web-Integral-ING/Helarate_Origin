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
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: backgroundColor,
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
        ),
      ),
    );
  }
}

