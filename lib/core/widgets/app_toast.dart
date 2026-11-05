import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ToastKind { success, error, info, warning }

class _ToastData {
  final int id;
  final ToastKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  _ToastData({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });
}

/// Notificaciones al estilo HeroUI: tarjeta redondeada con borde sutil,
/// variante "flat" con color semántico, barra de progreso, pausa al pasar el
/// cursor, cierre con swipe y apilado de varias notificaciones.
class AppToast {
  AppToast._();

  static const int _maxVisible = 3;
  static final ValueNotifier<List<_ToastData>> _toasts = ValueNotifier([]);
  static OverlayEntry? _entry;
  static int _nextId = 0;

  static void _show({
    required BuildContext context,
    required ToastKind kind,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (kind == ToastKind.success) {
      HapticFeedback.lightImpact();
    } else if (kind == ToastKind.error) {
      HapticFeedback.mediumImpact();
    }

    // Evita duplicados idénticos seguidos (p. ej. al escanear varias veces).
    final current = _toasts.value;
    if (current.isNotEmpty &&
        current.last.title == title &&
        current.last.message == message) {
      _toasts.value = [
        ...current.sublist(0, current.length - 1),
        _ToastData(
          id: _nextId++,
          kind: kind,
          title: title,
          message: message,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ];
    } else {
      final next = [
        ...current,
        _ToastData(
          id: _nextId++,
          kind: kind,
          title: title,
          message: message,
          duration: duration,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ];
      // Descarta las más antiguas si se acumulan demasiadas.
      _toasts.value = next.length > _maxVisible
          ? next.sublist(next.length - _maxVisible)
          : next;
    }

    if (_entry == null || !(_entry!.mounted)) {
      _entry = OverlayEntry(builder: (_) => const _ToastHost());
      overlay.insert(_entry!);
    }
  }

  static void _remove(int id) {
    _toasts.value = _toasts.value.where((t) => t.id != id).toList();
    if (_toasts.value.isEmpty) {
      _entry?.remove();
      _entry = null;
    }
  }

  static void dismissAll() {
    _toasts.value = [];
    _entry?.remove();
    _entry = null;
  }

  static void showSuccess(BuildContext context, String message,
      {String title = 'Listo', String? actionLabel, VoidCallback? onAction}) {
    _show(
      context: context,
      kind: ToastKind.success,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(BuildContext context, String message,
      {String title = 'Algo salió mal',
      String? actionLabel,
      VoidCallback? onAction}) {
    _show(
      context: context,
      kind: ToastKind.error,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 6),
    );
  }

  static void showInfo(BuildContext context, String message,
      {String title = 'Aviso', String? actionLabel, VoidCallback? onAction}) {
    _show(
      context: context,
      kind: ToastKind.info,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(BuildContext context, String message,
      {String title = 'Atención',
      String? actionLabel,
      VoidCallback? onAction}) {
    _show(
      context: context,
      kind: ToastKind.warning,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 5),
    );
  }
}

class _ToastHost extends StatelessWidget {
  const _ToastHost();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDesktop = mq.size.width >= 800;

    return Positioned(
      right: isDesktop ? 20 : 12,
      left: isDesktop ? null : 12,
      // En móvil se deja espacio para la barra de navegación inferior.
      bottom: mq.padding.bottom + (isDesktop ? 20 : 84),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: ValueListenableBuilder<List<_ToastData>>(
            valueListenable: AppToast._toasts,
            builder: (context, list, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in list)
                  _ToastCard(
                    key: ValueKey(t.id),
                    data: t,
                    onDone: () => AppToast._remove(t.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onDone;
  const _ToastCard({super.key, required this.data, required this.onDone});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 240),
  );
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: widget.data.duration,
  );
  late final CurvedAnimation _enter =
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _timer.forward();
    _timer.addStatusListener((s) {
      if (s == AnimationStatus.completed) _close();
    });
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer.stop();
    await _anim.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _enter.dispose();
    _anim.dispose();
    _timer.dispose();
    super.dispose();
  }

  ({IconData icon, Color color, Color textLight})? _styleOf(ToastKind k) {
    switch (k) {
      case ToastKind.success:
        return (icon: Icons.check_circle_rounded, color: const Color(0xFF17C964), textLight: const Color(0xFF12A150));
      case ToastKind.error:
        return (icon: Icons.cancel_rounded, color: const Color(0xFFF31260), textLight: const Color(0xFFC20E4D));
      case ToastKind.warning:
        return (icon: Icons.warning_rounded, color: const Color(0xFFF5A524), textLight: const Color(0xFFC4841D));
      case ToastKind.info:
        return (icon: Icons.info_rounded, color: const Color(0xFF338EF7), textLight: const Color(0xFF006FEE));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = widget.data;
    final st = _styleOf(d.kind)!;

    // Superficie "content1" de HeroUI + tinte semántico (variante flat).
    final base = isDark ? const Color(0xFF18181B) : Colors.white;
    final bg = Color.alphaBlend(st.color.withValues(alpha: isDark ? 0.16 : 0.10), base);
    final border = st.color.withValues(alpha: isDark ? 0.40 : 0.35);
    final titleColor = isDark ? st.color : st.textLight;
    final descColor = isDark ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46);

    return SizeTransition(
      sizeFactor: _enter,
      axisAlignment: 1,
      child: FadeTransition(
        opacity: _enter,
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, child) => Transform.translate(
            offset: Offset(_drag + (1 - _enter.value) * 36, 0),
            child: Transform.scale(
              scale: 0.94 + 0.06 * _enter.value,
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: MouseRegion(
              onEnter: (_) => _timer.stop(),
              onExit: (_) {
                if (!_closing) _timer.forward();
              },
              child: GestureDetector(
                onHorizontalDragUpdate: (e) => setState(() => _drag += e.delta.dx),
                onHorizontalDragEnd: (_) {
                  if (_drag.abs() > 70) {
                    _close();
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(st.icon, color: st.color, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    d.title,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (d.message.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      d.message,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: descColor,
                                        fontSize: 13,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  if (d.actionLabel != null) ...[
                                    const SizedBox(height: 8),
                                    _ActionPill(
                                      label: d.actionLabel!,
                                      color: st.color,
                                      textColor: titleColor,
                                      onTap: () {
                                        d.onAction?.call();
                                        _close();
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            InkResponse(
                              onTap: _close,
                              radius: 16,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: descColor.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _timer,
                        builder: (context, _) => LinearProgressIndicator(
                          value: 1 - _timer.value,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(st.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _ActionPill({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
