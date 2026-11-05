import 'package:flutter/material.dart';
import '../../core/widgets/app_loader.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../../main.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../blocs/dashboard/dashboard_event.dart';
import '../blocs/inventario/inventario_bloc.dart';
import '../blocs/inventario/inventario_event.dart';
import '../blocs/venta/venta_bloc.dart';
import '../blocs/venta/venta_event.dart';
import '../../domain/models/tenant_model.dart';

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

  Future<void> _eliminarTenant(String tenantId, String tenantNombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Empresa?'),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente "$tenantNombre"?\n\n'
          'Esta acción borrará todos sus productos, ventas, empleados y configuraciones asociadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _client.from('tenants').delete().eq('id', tenantId);
      if (mounted) {
        AppToast.showSuccess(context, 'Empresa "$tenantNombre" eliminada.');
        _loadTenants();
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al eliminar tenant: $e');
    }
  }

  Future<void> _toggleActivoTenant(String tenantId, bool estadoActual, String tenantNombre) async {
    try {
      await _client.from('tenants').update({'activo': !estadoActual}).eq('id', tenantId);
      if (mounted) {
        AppToast.showSuccess(
          context,
          !estadoActual ? 'Empresa "$tenantNombre" activada.' : 'Empresa "$tenantNombre" suspendida/desactivada.',
        );
        _loadTenants();
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cambiar estado: $e');
    }
  }

  Future<void> _impersonateTenant(String tenantId, String tenantNombre) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('profiles').update({'tenant_id': tenantId}).eq('id', userId);
      
      // Obtener datos del tenant seleccionado
      final tenantData = await _client.from('tenants').select().eq('id', tenantId).maybeSingle();
      if (tenantData != null && mounted) {
        final tenantModel = TenantModel.fromJson(tenantData);
        context.read<AuthBloc>().add(TenantUpdated(tenantModel));
      }
      
      // Recargar datos de insumos, ventas y dashboard para el tenant seleccionado
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardEvent());
        context.read<InventarioBloc>().add(LoadInventario());
        context.read<VentaBloc>().add(LoadVentasEvent());
      }
      
      if (mounted) {
        AppToast.showSuccess(context, 'Ingresando a ' + tenantNombre);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cambiar de tenant: ' + e.toString());
    }
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_business_rounded, color: context.brand, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dar de Alta Empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Crea un nuevo tenant y asigna su dueño', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _empresaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Empresa',
                  prefixIcon: Icon(Icons.storefront_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Dueño',
                  prefixIcon: Icon(Icons.person_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo del Dueño',
                  prefixIcon: Icon(Icons.email_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _crearTenant,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: _isLoading
                      ? const AppSpinner(size: 20, color: Colors.white)
                      : const Text('Registrar Negocio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantList(BuildContext context) {
    if (_isLoadingTenants) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: AppLoader()));
    }
    if (_tenants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No hay clientes registrados.'),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tenants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final t = _tenants[idx];
        final id = t['id']?.toString() ?? '';
        final nombre = t['nombre']?.toString() ?? 'Sin nombre';
        final activo = t['activo'] != false;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.borderColor),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: activo ? context.brand.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
              child: Icon(
                activo ? Icons.business_rounded : Icons.block_rounded,
                color: activo ? context.brand : Colors.red,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: activo ? null : TextDecoration.lineThrough,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activo ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activo ? 'Activo' : 'Suspendido',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: activo ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'ID: ${id.length > 8 ? id.substring(0, 8) + '...' : id}',
              style: TextStyle(fontSize: 12, color: context.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: activo ? 'Suspender/Desactivar' : 'Reactivar',
                  icon: Icon(
                    activo ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                    color: activo ? Colors.orange : Colors.green,
                  ),
                  onPressed: () => _toggleActivoTenant(id, activo, nombre),
                ),
                IconButton(
                  tooltip: 'Eliminar permanentemente',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () => _eliminarTenant(id, nombre),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Entrar'),
                  onPressed: () => _impersonateTenant(id, nombre),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMobile = ancho < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Panel de SuperAdmin'),
        backgroundColor: context.brand,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(SignOutRequested()),
          )
        ],
      ),
      body: esMobile
          // Vista Móvil: formulario arriba y lista debajo en scroll continuo
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildForm(context),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Tus Clientes (${_tenants.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTenantList(context),
                ],
              ),
            )
          // Vista Escritorio / Tablet ancha: 2 columnas balanceadas
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(child: _buildForm(context)),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.apartment_rounded, size: 22),
                            const SizedBox(width: 8),
                            Text('Tus Clientes (${_tenants.length})',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(child: _buildTenantList(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
