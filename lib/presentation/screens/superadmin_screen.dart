import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empresaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _crearTenant() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      
      // Crear Tenant
      final tenantRes = await client.from('tenants').insert({
        'nombre': _empresaCtrl.text.trim(),
      }).select().single();
      final tenantId = tenantRes['id'];

      // Crear Perfil pendiente (sin auth user id, usa UUID dummy temporal)
      await client.from('profiles').insert({
        'id': const Uuid().v4(),
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'rol': 'dueño',
        'tenant_id': tenantId,
      });

      if (mounted) {
        AppToast.showSuccess(context, 'Empresa creada. El dueño puede activar su cuenta ahora.');
        _empresaCtrl.clear();
        _nombreCtrl.clear();
        _emailCtrl.clear();
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al crear tenant: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Panel de SuperAdmin'),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(SignOutRequested()),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 64, color: AppTheme.primary),
                      const SizedBox(height: 16),
                      const Text('Crear Nueva Nevería', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _empresaCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre de la Empresa', prefixIcon: Icon(Icons.store)),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre del Dueño', prefixIcon: Icon(Icons.person)),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Correo del Dueño', prefixIcon: Icon(Icons.email)),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _crearTenant,
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Registrar Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
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
