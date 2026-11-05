import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';

/// Cambia este valor cuando el Aviso de Privacidad cambie, para volver a
/// pedir la aceptación a todos los usuarios.
const String kAvisoVersion = '2026-11';

/// Pide la aceptación del Aviso de Privacidad UNA sola vez por usuario.
///
/// La aceptación se guarda en la base de datos (profiles.aceptado_aviso_at) y
/// como respaldo en el dispositivo, así que no vuelve a aparecer en cada login.
class PrivacyGate extends StatefulWidget {
  final Widget child;
  const PrivacyGate({super.key, required this.child});

  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  String _prefsKey(String userId) => 'aviso_aceptado_${userId}_$kAvisoVersion';

  Future<void> _maybeAsk() async {
    if (!mounted || _dialogOpen) return;
    final state = context.read<AuthBloc>().state;
    if (state is! Authenticated) return;
    if (state.usuario.aceptadoAvisoAt != null) return;

    // Respaldo local por si la base de datos aún no tiene la columna.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey(state.usuario.id)) == true) return;
    if (!mounted) return;

    _dialogOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PrivacyNoticeDialog(),
    );
    _dialogOpen = false;
    if (!mounted) return;

    final bloc = context.read<AuthBloc>();
    if (accepted == true) {
      await prefs.setBool(_prefsKey(state.usuario.id), true);
      bloc.add(PrivacyAccepted(kAvisoVersion));
    } else {
      bloc.add(SignOutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) =>
          next is Authenticated &&
          (prev is! Authenticated ||
              prev.usuario.id != next.usuario.id),
      listener: (_, __) => _maybeAsk(),
      child: widget.child,
    );
  }
}

class PrivacyNoticeDialog extends StatefulWidget {
  const PrivacyNoticeDialog({super.key});

  @override
  State<PrivacyNoticeDialog> createState() => _PrivacyNoticeDialogState();
}

class _PrivacyNoticeDialogState extends State<PrivacyNoticeDialog> {
  bool _read = false;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: brand),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Aviso de Privacidad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'En cumplimiento con la Ley General de Protección de Datos '
                  'Personales (LGPDPPSO), tus datos se usarán únicamente para '
                  'autenticación, control de accesos por rol y auditoría dentro '
                  'del sistema de ventas e inventarios.',
                  style: TextStyle(
                      fontSize: 13, height: 1.45, color: context.textMuted),
                ),
                const SizedBox(height: 14),
                for (final item in const [
                  'Puedes acceder, rectificar, cancelar u oponerte al uso de tus datos desde tu Perfil.',
                  'Solo verás esta pantalla una vez; guardamos la fecha de tu aceptación.',
                  'Tus datos están aislados por empresa y protegidos con seguridad a nivel de fila.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item,
                              style: const TextStyle(fontSize: 12.5, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _read = !_read),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _read,
                        onChanged: (v) => setState(() => _read = v ?? false),
                      ),
                      const Expanded(
                        child: Text('He leído y acepto el Aviso de Privacidad',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Rechazar y salir',
                style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            onPressed: _read ? () => Navigator.of(context).pop(true) : null,
            child: const Text('Aceptar y continuar'),
          ),
        ],
      ),
    );
  }
}
