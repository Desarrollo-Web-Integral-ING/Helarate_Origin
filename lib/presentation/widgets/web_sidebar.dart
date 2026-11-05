import '../../core/widgets/user_avatar.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/business_icon_helper.dart';
import '../../domain/models/tenant_model.dart';
import '../../domain/models/usuario_perfil.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../screens/perfil_screen.dart';
import '../screens/hardware_screen.dart';
import '../screens/turnos_screen.dart' show kTurnosTabIndex;
import '../screens/permisos_screen.dart' show kPermisosTabIndex;
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';

class WebSidebar extends StatelessWidget {
  final bool isCollapsed;
  final bool isEmployee;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onToggleCollapse;

  const WebSidebar({
    super.key,
    required this.isCollapsed,
    required this.isEmployee,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final perms = getIt<PermissionService>();
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.usuario : null;
    final tenant = authState is Authenticated ? authState.tenant : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final businessName = tenant?.nombre ?? 'Mi Negocio';
    final brandColor = AppTheme.parseHexColor(tenant?.colorPrimario);
    final primaryGradient = AppTheme.createCustomGradient(brandColor);

    final sidebarBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final sidebarBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final textHeadColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSubColor =
        isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;

    final initials = user == null || user.nombre.trim().isEmpty
        ? 'UN'
        : user.nombre
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isCollapsed ? 88 : 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Collapse Icon Toggle Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed) ...[
                  Expanded(
                    child: Row(
                      children: [
                        _buildLogoWidget(tenant, brandColor, primaryGradient),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textHeadColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: textSubColor),
                    onPressed: onToggleCollapse,
                  ),
                ] else ...[
                  _buildLogoWidget(tenant, brandColor, primaryGradient),
                  IconButton(
                    icon:
                        Icon(Icons.chevron_right_rounded, color: textSubColor),
                    onPressed: onToggleCollapse,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Menú: cada opción aparece solo si el usuario tiene el permiso.
          Expanded(
            child: ListenableBuilder(
              listenable: perms,
              builder: (context, _) {
                final entradas = <Widget>[];

                void agregar({
                  required int index,
                  required IconData activo,
                  required IconData inactivo,
                  required String label,
                  required bool visible,
                }) {
                  if (!visible) return;
                  entradas.add(_sidebarItem(
                    context,
                    index: index,
                    activeIcon: activo,
                    inactiveIcon: inactivo,
                    label: label,
                    gradient: primaryGradient,
                    isDark: isDark,
                  ));
                  entradas.add(const SizedBox(height: 8));
                }

                agregar(
                  index: 0,
                  activo: Icons.grid_view_rounded,
                  inactivo: Icons.grid_view_outlined,
                  label: 'Inicio',
                  visible: perms.can(Permiso.dashboardVer),
                );
                agregar(
                  index: 1,
                  activo: Icons.inventory_2_rounded,
                  inactivo: Icons.inventory_2_outlined,
                  label: 'Insumos',
                  visible: perms.can(Permiso.insumosVer),
                );
                agregar(
                  index: 2,
                  activo: Icons.shopping_bag_rounded,
                  inactivo: Icons.shopping_bag_outlined,
                  label: 'Productos',
                  visible: perms.can(Permiso.catalogoVer),
                );
                agregar(
                  index: 3,
                  activo: Icons.point_of_sale_rounded,
                  inactivo: Icons.point_of_sale_outlined,
                  label: 'Ventas',
                  visible: perms.can(Permiso.ventasVer),
                );
                agregar(
                  index: 4,
                  activo: Icons.bar_chart_rounded,
                  inactivo: Icons.bar_chart_outlined,
                  label: 'Stats',
                  visible: perms.can(Permiso.estadisticasVer),
                );
                agregar(
                  index: kTurnosTabIndex,
                  activo: Icons.timer_rounded,
                  inactivo: Icons.timer_outlined,
                  label: 'Turnos',
                  visible: perms.canAny(const [Permiso.turnosPropios, Permiso.turnosAdministrar]),
                );
                agregar(
                  index: 5,
                  activo: Icons.people_alt,
                  inactivo: Icons.people_alt_outlined,
                  label: 'Usuarios',
                  visible: perms.can(Permiso.usuariosVer),
                );
                agregar(
                  index: kPermisosTabIndex,
                  activo: Icons.admin_panel_settings_rounded,
                  inactivo: Icons.admin_panel_settings_outlined,
                  label: 'Permisos',
                  visible: perms.can(Permiso.permisosAdministrar),
                );
                agregar(
                  index: 6,
                  activo: Icons.palette_rounded,
                  inactivo: Icons.palette_outlined,
                  label: 'Personalizar',
                  visible: perms.can(Permiso.personalizacionVer),
                );
                agregar(
                  index: 7,
                  activo: Icons.tune_rounded,
                  inactivo: Icons.tune_outlined,
                  label: 'Campos',
                  visible: perms.can(Permiso.personalizacionVer),
                );

                // Equipos de ESTA terminal (abre otra pantalla).
                if (perms.can(Permiso.equiposConfigurar)) {
                  entradas.add(_sidebarItem(
                    context,
                    index: 99,
                    activeIcon: Icons.print_rounded,
                    inactiveIcon: Icons.print_outlined,
                    label: 'Equipos de caja',
                    gradient: primaryGradient,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HardwareScreen()),
                    ),
                  ));
                  entradas.add(const SizedBox(height: 8));
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: entradas,
                );
              },
            ),
          ),

          // User Profile & Quick Theme Switcher
          if (user != null) ...[
            Divider(height: 1, thickness: 1, color: sidebarBorder),
            const SizedBox(height: 8),
            _buildProfileTile(
              context,
              user: user,
              initials: initials,
              brandColor: brandColor,
              textHeadColor: textHeadColor,
              isDark: isDark,
            ),
            const SizedBox(height: 4),

            // Logout row
            _buildLogoutButton(context, isDark: isDark),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLogoWidget(
      TenantModel? tenant, Color brandColor, LinearGradient primaryGradient) {
    if (tenant?.logoUrl != null && tenant!.logoUrl!.isNotEmpty) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: brandColor.withValues(alpha: 0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.memory(
            base64Decode(tenant.logoUrl!.contains(',')
                ? tenant.logoUrl!.split(',').last
                : tenant.logoUrl!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              BusinessIconHelper.getIcon(tenant.logoIcon),
              color: brandColor,
              size: 24,
            ),
          ),
        ),
      );
    }

    return ShaderMask(
      shaderCallback: (bounds) => primaryGradient.createShader(bounds),
      child: Icon(
        BusinessIconHelper.getIcon(tenant?.logoIcon),
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context, {
    required UsuarioPerfil user,
    required String initials,
    required Color brandColor,
    required Color textHeadColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PerfilScreen()),
        );
      },
      child: Tooltip(
        message: isCollapsed ? '${user.nombre} (${user.rol.toUpperCase()})' : '',
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 14,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: brandColor.withValues(alpha: 0.5), width: 1.5),
                ),
                child: UserAvatar(style: user.avatarStyle, seed: user.avatarSeed ?? '', name: user.nombre, size: 40, png: user.avatarPng),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.nombre,
                        style: TextStyle(
                          color: textHeadColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.rol.toUpperCase(),
                        style: TextStyle(
                          color: user.isEmployee
                              ? Colors.blue
                              : (isDark
                                  ? const Color(0xFFC084FC)
                                  : Colors.purple),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      key: ValueKey(isDark),
                      size: 19,
                      color: isDark
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
                  onPressed: () {
                    context.read<AuthBloc>().add(ToggleThemeRequested());
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, {required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Tooltip(
        message: isCollapsed ? 'Cerrar Sesión' : '',
        child: GestureDetector(
          onTap: () {
            context.read<AuthBloc>().add(SignOutRequested());
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF450A0A) : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF991B1B) : Colors.red[100]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: isDark ? const Color(0xFFF87171) : Colors.red,
                  size: 20,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171) : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarItem(
    BuildContext context, {
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required LinearGradient gradient,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final isActive = onTap == null && currentIndex == index;
    final itemContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 0 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        gradient: isActive ? gradient : null,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1)
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : inactiveIcon,
            color: isActive
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary),
            size: 22,
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textPrimary),
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: isCollapsed ? label : '',
      child: GestureDetector(
        onTap: onTap ?? () => onTabSelected(index),
        child: itemContent,
      ),
    );
  }
}

