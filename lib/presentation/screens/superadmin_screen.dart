import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../../main.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _empresaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoadingTenants = true;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    setState(() => _isLoadingTenants = true);
    try {
      final res = await _client.from('tenants').select().order('created_at');
      setState(() {
        _tenants = List<Map<String, dynamic>>.from(res);
        _isLoadingTenants = false;
      });
    } catch (e) {
      setState(() => _isLoadingTenants = false);
    }
  }

  Future<void> _crearTenant() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Crear Tenant
      final tenantRes = await _client.from('tenants').insert({
        'nombre': _empresaCtrl.text.trim(),
      }).select().single();
      final tenantId = tenantRes['id'];

      // Crear Invitación con rol de dueño
      await _client.from('invitaciones').insert({
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'tenant_id': tenantId,
        'rol': 'dueño',
      });

      if (mounted) {
        AppToast.showSuccess(context, 'Empresa creada. El dueño puede activar su cuenta.');
        _empresaCtrl.clear();
        _nombreCtrl.clear();
        _emailCtrl.clear();
        _loadTenants();
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al crear tenant: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _impersonateTenant(String tenantId, String tenantNombre) async {
    try {
      final userId = _client.auth.currentUser!.id;
      // Actualizamos nuestro propio perfil para que apunte al tenant seleccionado
      await _client.from('profiles').update({'tenant_id': tenantId}).eq('id', userId);
      
      if (mounted) {
        AppToast.showSuccess(context, 'Ingresando a $tenantNombre');
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cambiar de tenant');
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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar de Clientes
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tus Clientes (Tenants)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoadingTenants
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _tenants.length,
                          itemBuilder: (context, idx) {
                            final t = _tenants[idx];
                            return ListTile(
                              leading: const Icon(Icons.business),
                              title: Text(t['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Ver sistema completo'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () => _impersonateTenant(t['id'], t['nombre']),
                            );
                          },
                        ),
                  )
                ],
              ),
            ),
          ),
          
          // Formulario Nuevo Cliente
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 48, color: AppTheme.primary),
                        const SizedBox(height: 16),
                        const Text('Dar de Alta Nueva Nevería', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }
}
