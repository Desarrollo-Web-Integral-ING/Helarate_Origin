import 'package:flutter/material.dart';
import 'dart:async';

class AppToast {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void _showOverlay(BuildContext context, Widget content, Color bgColor, Duration duration) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _timer?.cancel();

    final overlayState = Overlay.of(context, rootOverlay: true);
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Positioned(
          bottom: viewInsets.bottom + 40.0,
          left: 16.0,
          right: 16.0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: content,
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
    
    _timer = Timer(duration, () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  static void showSuccess(BuildContext context, String message) {
    _showOverlay(
      context,
      Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
      const Color(0xFF2E7D32),
      const Duration(seconds: 3),
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    _showOverlay(
      context,
      Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      const Color(0xFFD32F2F),
      const Duration(seconds: 4),
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showOverlay(
      context,
      Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
      const Color(0xFFE65100),
      const Duration(seconds: 3),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showOverlay(
      context,
      Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
      const Color(0xFF1976D2),
      const Duration(seconds: 3),
    );
  }
}
