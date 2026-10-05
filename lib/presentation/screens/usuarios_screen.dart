import 'package:flutter/material.dart';
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
