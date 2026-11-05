import '../../core/widgets/avatar_image.dart';
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

          // Menu navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _sidebarItem(
                  context,
                  index: 0,
                  activeIcon: Icons.grid_view_rounded,
                  inactiveIcon: Icons.grid_view_outlined,
                  label: 'Inicio',
                  gradient: primaryGradient,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _sidebarItem(
                  context,
                  index: 1,
                  activeIcon: Icons.inventory_2_rounded,
                  inactiveIcon: Icons.inventory_2_outlined,
                  label: 'Insumos',
                  gradient: primaryGradient,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _sidebarItem(
                  context,
                  index: 2,
                  activeIcon: Icons.shopping_bag_rounded,
                  inactiveIcon: Icons.shopping_bag_outlined,
                  label: 'Productos',
                  gradient: primaryGradient,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _sidebarItem(
                  context,
                  index: 3,
                  activeIcon: Icons.point_of_sale_rounded,
                  inactiveIcon: Icons.point_of_sale_outlined,
                  label: 'Ventas',
                  gradient: primaryGradient,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                if (!isEmployee) ...[
                  _sidebarItem(
                    context,
                    index: 4,
                    activeIcon: Icons.bar_chart_rounded,
                    inactiveIcon: Icons.bar_chart_outlined,
                    label: 'Stats',
                    gradient: primaryGradient,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  if (user != null &&
                      (user.rol == 'dueño' ||
                          user.rol == 'admin' ||
                          user.rol == 'superadmin')) ...[
                    _sidebarItem(
                      context,
                      index: 5,
                      activeIcon: Icons.people_alt,
                      inactiveIcon: Icons.people_alt_outlined,
                      label: 'Usuarios',
                      gradient: primaryGradient,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _sidebarItem(
                      context,
                      index: 7,
                      activeIcon: Icons.tune_rounded,
                      inactiveIcon: Icons.tune_outlined,
                      label: 'Campos',
                      gradient: primaryGradient,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _sidebarItem(
                      context,
                      index: 6,
                      activeIcon: Icons.palette_rounded,
                      inactiveIcon: Icons.palette_outlined,
                      label: 'Personalizar',
                      gradient: primaryGradient,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                // Equipos de ESTA terminal: disponible para todos los roles.
                _sidebarItem(
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
                ),
                const SizedBox(height: 8),
              ],
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
                child: AppAvatarImage(
                  url: user.avatarUrl,
                  size: 40,
                  fallbackInitial: initials,
                  backgroundColor: brandColor,
                ),
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

