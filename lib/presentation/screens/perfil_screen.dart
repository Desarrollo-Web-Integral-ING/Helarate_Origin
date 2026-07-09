import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/usuario_perfil.dart';
import '../../domain/repositories/auth_repository.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';

/// Pantalla completa de Perfil. Sustituye al antiguo PerfilDialog flotante,
/// mostrando la información del usuario y los Derechos ARCO (LGPDPPSO) en
/// una vista dedicada, accesible desde la navegación lateral (web) y el
/// menú (móvil).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final AuthRepository _authRepository = getIt<AuthRepository>();
  final TextEditingController _nombreController = TextEditingController();

  bool _editandoNombre = false;
  bool _guardandoNombre = false;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  String _initialsOf(String nombre) {
    return nombre.trim().isEmpty
        ? 'UN'
        : nombre
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase();
  }

  void _mostrarSnack(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Rectificación (R): edición del nombre con actualización en Supabase.
  // ---------------------------------------------------------------------

  void _iniciarEdicion(UsuarioPerfil perfil) {
    _nombreController.text = perfil.nombre;
    setState(() => _editandoNombre = true);
  }

  void _cancelarEdicion() {
    setState(() => _editandoNombre = false);
  }

  Future<void> _guardarNombre() async {
    final nuevoNombre = _nombreController.text.trim();
    if (nuevoNombre.isEmpty) {
      _mostrarSnack('El nombre no puede estar vacío.', esError: true);
      return;
    }

    setState(() => _guardandoNombre = true);
    try {
      final actualizado = await _authRepository.updateProfile(nuevoNombre);
      if (!mounted) return;
      context.read<AuthBloc>().add(ProfileUpdated(actualizado));
      setState(() {
        _editandoNombre = false;
        _guardandoNombre = false;
      });
      _mostrarSnack('Perfil actualizado correctamente.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardandoNombre = false);
      _mostrarSnack('No se pudo actualizar el perfil: $e', esError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Acceso (A): exportación de datos personales en formato JSON.
  // ---------------------------------------------------------------------

  Future<void> _exportarDatos(UsuarioPerfil perfil) async {
    final Map<String, dynamic> data = {
      'tipo_solicitud': 'Derecho de Acceso (ARCO)',
      'fecha_solicitud': DateTime.now().toIso8601String(),
      'usuario': perfil.toJson(),
      'aviso_privacidad': 'Aceptado explícitamente',
      'ley_aplicable':
          'Ley General de Protección de Datos Personales en Posesión de Sujetos Obligados (LGPDPPSO)',
    };

    final String jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: jsonStr));

    _mostrarSnack('Datos exportados y copiados al portapapeles en formato JSON.');

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('audit_logs').insert({
          'user_id': userId,
          'action': 'ARCO_ACCESS',
          'table_name': 'profiles',
          'record_id': userId,
          'descripcion':
              'Ejercicio de Derecho ARCO: Acceso y exportación de datos personales del usuario en formato JSON.',
        });
      }
    } catch (e) {
      // La auditoría es best-effort: no debe bloquear la exportación.
      // ignore: avoid_print
      print('Error al guardar log de acceso en auditoría: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tus datos exportados (JSON)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'De acuerdo con el Derecho de Acceso (ARCO), aquí tienes toda la información personal almacenada en tu cuenta:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Cancelación / Oposición (C/O): eliminación definitiva de la cuenta.
  // ---------------------------------------------------------------------

  void _confirmarEliminacion() {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool puedeEliminar = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(child: Text('Confirmar Cancelación')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Estás seguro de que deseas ejercer tu Derecho de Cancelación (ARCO)?\n\n'
                      'Esta acción eliminará de forma irreversible tu perfil de usuario y todos '
                      'tus registros de insumos y ventas de la base de datos de manera segura.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Escribe ELIMINAR para confirmar:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'ELIMINAR'),
                      onChanged: (value) {
                        setDialogState(() => puedeEliminar = value.trim() == 'ELIMINAR');
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withValues(alpha: 0.35),
                  ),
                  onPressed: puedeEliminar
                      ? () {
                          Navigator.pop(ctx);
                          context.read<AuthBloc>().add(DeleteAccountRequested());
                        }
                      : null,
                  child: const Text('Eliminar definitivamente'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final perfil = state.usuario;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Mi Perfil')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(perfil),
                      const SizedBox(height: 24),
                      _buildArcoCard(perfil),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(UsuarioPerfil perfil) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initialsOf(perfil.nombre),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_editandoNombre) ...[
            Text(
              perfil.nombre,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: perfil.isOwner ? Colors.purple[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                perfil.rol.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: perfil.isOwner ? Colors.purple : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    perfil.email.isNotEmpty ? perfil.email : 'Sin correo registrado',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Editar nombre'),
              onPressed: () => _iniciarEdicion(perfil),
            ),
          ] else ...[
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              textAlign: TextAlign.center,
              enabled: !_guardandoNombre,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardandoNombre ? null : _cancelarEdicion,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _guardandoNombre ? null : _guardarNombre,
                    child: _guardandoNombre
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArcoCard(UsuarioPerfil perfil) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Derechos ARCO (LGPDPPSO)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tienes derecho a Acceder, Rectificar, Cancelar u Oponerte al uso de tus datos personales.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          _arcoTile(
            icon: Icons.download_rounded,
            title: 'Acceso',
            subtitle: 'Descarga tus datos personales en formato JSON.',
            actionLabel: 'Exportar',
            onTap: () => _exportarDatos(perfil),
          ),
          const SizedBox(height: 12),
          _arcoTile(
            icon: Icons.edit_note_rounded,
            title: 'Rectificación',
            subtitle: 'Corrige tu nombre desde la tarjeta de perfil.',
            actionLabel: 'Editar',
            onTap: () => _iniciarEdicion(perfil),
          ),
          const SizedBox(height: 12),
          _arcoTile(
            icon: Icons.delete_forever_rounded,
            title: 'Cancelación / Oposición',
            subtitle: 'Elimina tu cuenta y todos tus datos de forma permanente.',
            actionLabel: 'Eliminar',
            esDestructivo: true,
            onTap: _confirmarEliminacion,
          ),
        ],
      ),
    );
  }

  Widget _arcoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    bool esDestructivo = false,
  }) {
    final color = esDestructivo ? Colors.redAccent : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esDestructivo ? Colors.red[50] : const Color(0xFFF0F1FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: esDestructivo ? Colors.redAccent : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: color),
            onPressed: onTap,
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
