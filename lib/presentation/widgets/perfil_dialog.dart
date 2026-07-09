import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/usuario_perfil.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilDialog extends StatelessWidget {
  final UsuarioPerfil perfil;

  const PerfilDialog({super.key, required this.perfil});

  static void show(BuildContext context, UsuarioPerfil perfil) {
    showDialog(
      context: context,
      builder: (_) => PerfilDialog(perfil: perfil),
    );
  }

  void _exportarDatos(BuildContext context) async {
    final Map<String, dynamic> data = {
      'tipo_solicitud': 'Derecho de Acceso (ARCO)',
      'fecha_solicitud': DateTime.now().toIso8601String(),
      'usuario': perfil.toJson(),
      'aviso_privacidad': 'Aceptado explícitamente',
      'ley_aplicable': 'Ley General de Protección de Datos Personales en Posesión de Sujetos Obligados (LGPDPPSO)',
    };

    final String jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    Clipboard.setData(ClipboardData(text: jsonStr));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📥 Datos exportados y copiados al portapapeles en formato JSON.'),
        backgroundColor: Colors.green,
      ),
    );

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('audit_logs').insert({
          'user_id': userId,
          'action': 'ARCO_ACCESS',
          'table_name': 'profiles',
          'record_id': userId,
          'descripcion': 'Ejercicio de Derecho ARCO: Acceso y exportación de datos personales del usuario en formato JSON.',
        });
      }
    } catch (e) {
      print('Error al guardar log de acceso en auditoría: $e');
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirmar Cancelación'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas ejercer tu Derecho de Cancelación (ARCO)?\n\n'
          'Esta acción eliminará de forma irreversible tu perfil de usuario y todos tus registros de insumos y ventas de la base de datos de manera segura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo confirmación
              Navigator.pop(context); // Cerrar diálogo perfil
              context.read<AuthBloc>().add(DeleteAccountRequested());
            },
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = perfil.nombre.trim().isEmpty 
        ? 'UN' 
        : perfil.nombre.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primary,
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              perfil.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: perfil.isOwner ? Colors.purple[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Derechos ARCO (LGPDPPSO)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tienes derecho a Acceder, Rectificar, Cancelar u Oponerte al uso de tus datos. Usa las siguientes opciones:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Descargar mis datos (Acceso)'),
              onPressed: () => _exportarDatos(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.redAccent),
                foregroundColor: Colors.redAccent,
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Eliminar cuenta (Cancelación)'),
              onPressed: () => _confirmarEliminacion(context),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                elevation: 0,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
