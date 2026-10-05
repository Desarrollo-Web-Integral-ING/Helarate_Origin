import os
import re

APP_DIR = r'C:\Users\bhleo\Desktop\Personal Projects\New folder\nevero_app'

def create_usuarios_screen():
    path = os.path.join(APP_DIR, 'lib', 'presentation', 'screens', 'usuarios_screen.dart')
    content = """import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = true;
  String? _tenantId;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _tenantId = authState.usuario.tenantId;
    }
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    if (_tenantId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _client.from('profiles').select().eq('tenant_id', _tenantId!);
      final invites = await _client.from('invitaciones').select().eq('tenant_id', _tenantId!);
      
      final List<Map<String, dynamic>> combined = [];
      for (var d in data) {
        combined.add({...d, 'is_invite': false});
      }
      for (var i in invites) {
        combined.add({...i, 'is_invite': true, 'rol': i['rol'] ?? 'empleado'});
      }
      
      setState(() {
        _usuarios = combined;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppToast.showError(context, 'Error al cargar usuarios');
    }
  }

  void _showInviteModal() {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRol = 'empleado';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setModalState) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 24, right: 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invitar Nuevo Empleado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email)),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRol,
                  decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.badge)),
                  items: const [
                    DropdownMenuItem(value: 'empleado', child: Text('Empleado (Solo Ventas)')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador (Inventario y Reportes)')),
                  ],
                  onChanged: (v) => setModalState(() => selectedRol = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSubmitting ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        await _client.from('invitaciones').insert({
                          'nombre': nombreCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'rol': selectedRol,
                          'tenant_id': _tenantId,
                        });
                        if (mounted) {
                          AppToast.showSuccess(context, 'Invitación creada. El usuario ya puede activar su cuenta.');
                          Navigator.pop(context);
                          _loadUsuarios();
                        }
                      } catch(e) {
                        if (mounted) AppToast.showError(context, 'Error al invitar: $e');
                        setModalState(() => isSubmitting = false);
                      }
                    },
                    child: isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Enviar Invitación', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Usuarios y Empleados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteModal,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _usuarios.length,
              itemBuilder: (context, index) {
                final u = _usuarios[index];
                final isInvite = u['is_invite'] == true;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isInvite ? Colors.orange.shade100 : AppTheme.primary.withOpacity(0.1),
                      child: Icon(isInvite ? Icons.schedule : Icons.person, color: isInvite ? Colors.orange : AppTheme.primary),
                    ),
                    title: Text(u['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(u['email'] ?? ''),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (u['rol'] ?? 'empleado').toString().toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
"""
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def update_superadmin_screen():
    path = os.path.join(APP_DIR, 'lib', 'presentation', 'screens', 'superadmin_screen.dart')
    with open(path, 'r', encoding='utf-8') as f:
        code = f.read()

    new_code = """import 'package:flutter/material.dart';
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
"""
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_code)

def update_main_navigation():
    path = os.path.join(APP_DIR, 'lib', 'main.dart')
    with open(path, 'r', encoding='utf-8') as f:
        code = f.read()
    
    if "import 'presentation/screens/usuarios_screen.dart';" not in code:
        code = code.replace("import 'presentation/screens/superadmin_screen.dart';", "import 'presentation/screens/superadmin_screen.dart';\nimport 'presentation/screens/usuarios_screen.dart';")

    if "_sidebarItem(4, Icons.bar_chart_rounded" in code and "Usuarios" not in code:
        replacement = """_sidebarItem(4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Stats'),
                  const SizedBox(height: 8),
                  if (user.rol == 'dueño' || user.rol == 'admin' || user.rol == 'superadmin') ...[
                    _sidebarItem(5, Icons.people_alt, Icons.people_alt_outlined, 'Usuarios'),
                    const SizedBox(height: 8),
                  ],"""
        code = code.replace("_sidebarItem(4, Icons.bar_chart_rounded,\n                      Icons.bar_chart_outlined, 'Stats'),\n                  const SizedBox(height: 8),", replacement)
    
    if "case 4:" in code and "case 5:" not in code:
        replacement = """case 4:
        return const DashboardScreen();
      case 5:
        return const UsuariosScreen();"""
        code = code.replace("case 4:\n        return const DashboardScreen();", replacement)
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write(code)

if __name__ == '__main__':
    create_usuarios_screen()
    update_superadmin_screen()
    update_main_navigation()
    print("Done")
