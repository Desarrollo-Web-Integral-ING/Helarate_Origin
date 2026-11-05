import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';

/// Comprueba el permiso antes de una acción. Si falta, avisa y devuelve false.
bool puedeOAvisar(BuildContext context, Permiso p) {
  if (getIt<PermissionService>().can(p)) return true;
  AppToast.showWarning(
    context,
    'No tienes permiso para: ${p.etiqueta.toLowerCase()}.',
    title: 'Acceso restringido',
  );
  return false;
}

/// Muestra [child] solo si el usuario tiene el permiso. Si no, muestra
/// [fallback] (por defecto, una pantalla de "sin acceso").
class PermissionGate extends StatelessWidget {
  final Permiso permiso;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.permiso,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final perms = getIt<PermissionService>();
    return ListenableBuilder(
      listenable: perms,
      builder: (context, _) {
        if (perms.can(permiso)) return child;
        return fallback ?? AccessDeniedView(permiso: permiso);
      },
    );
  }
}

/// Oculta un widget pequeño (botón, ítem de menú) si falta el permiso.
class IfPermitted extends StatelessWidget {
  final Permiso permiso;
  final Widget child;
  const IfPermitted({super.key, required this.permiso, required this.child});

  @override
  Widget build(BuildContext context) {
    final perms = getIt<PermissionService>();
    return ListenableBuilder(
      listenable: perms,
      builder: (context, _) => perms.can(permiso) ? child : const SizedBox.shrink(),
    );
  }
}

class AccessDeniedView extends StatelessWidget {
  final Permiso? permiso;
  const AccessDeniedView({super.key, this.permiso});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.brand.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline_rounded, size: 42, color: context.brand),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No tienes acceso a esta sección',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  permiso == null
                      ? 'Pide a un administrador que te dé el permiso.'
                      : 'Necesitas el permiso "${permiso!.etiqueta}". Pide a un administrador que te lo conceda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
