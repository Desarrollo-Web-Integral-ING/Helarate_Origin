/// Catálogo de permisos de la app.
///
/// Las claves ([clave]) deben coincidir con las de la base de datos
/// (migracion_turnos_permisos.sql: función `permisos_default` y `tiene_permiso`).
enum Permiso {
  dashboardVer('dashboard.ver', 'Ver inicio', 'Vistas', 'Pantalla de inicio con resumen del día.'),

  insumosVer('insumos.ver', 'Ver insumos', 'Inventario', 'Consultar materia prima e insumos.'),
  insumosEditar('insumos.editar', 'Editar insumos', 'Inventario', 'Crear y eliminar insumos.'),
  catalogoVer('catalogo.ver', 'Ver catálogo', 'Inventario', 'Consultar productos de venta.'),
  catalogoEditar('catalogo.editar', 'Editar catálogo', 'Inventario', 'Crear, editar y eliminar productos.'),

  ventasVer('ventas.ver', 'Usar caja', 'Ventas', 'Cobrar y registrar ventas.'),
  ventasHistorial('ventas.historial', 'Ver historial de ventas', 'Ventas', 'Consultar ventas anteriores y sus tickets.'),
  ventasEliminar('ventas.eliminar', 'Eliminar ventas', 'Ventas', 'Borrar registros de ventas.'),

  estadisticasVer('estadisticas.ver', 'Ver estadísticas', 'Reportes', 'Gráficas, ganancias y reportes.'),

  usuariosVer('usuarios.ver', 'Ver usuarios', 'Equipo', 'Consultar la lista de usuarios.'),
  usuariosAdministrar('usuarios.administrar', 'Administrar usuarios', 'Equipo', 'Invitar y gestionar usuarios.'),
  personalizacionVer('personalizacion.ver', 'Personalizar el negocio', 'Negocio', 'Logo, colores, moneda y datos del negocio.'),
  equiposConfigurar('equipos.configurar', 'Configurar equipos de caja', 'Negocio', 'Impresora, cajón y lector de esta terminal.'),

  turnosPropios('turnos.propios', 'Registrar mi turno', 'Turnos', 'Marcar entrada, comida y salida propias.'),
  turnosAdministrar('turnos.administrar', 'Administrar turnos', 'Turnos', 'Ver al equipo, editar horarios y asistencias.'),

  permisosAdministrar('permisos.administrar', 'Administrar permisos', 'Seguridad', 'Cambiar qué puede hacer cada rol y usuario.');

  final String clave;
  final String etiqueta;
  final String grupo;
  final String descripcion;

  const Permiso(this.clave, this.etiqueta, this.grupo, this.descripcion);

  static Permiso? deClave(String clave) {
    for (final p in Permiso.values) {
      if (p.clave == clave) return p;
    }
    return null;
  }

  /// Roles que se pueden personalizar por empresa (el dueño siempre tiene todo).
  static const List<String> rolesEditables = ['admin', 'empleado'];

  /// Permisos que cada rol tiene por defecto (misma lógica que `permisos_default`
  /// en la base de datos).
  static Set<Permiso> porDefecto(String rol) {
    switch (rol) {
      case 'superadmin':
      case 'dueño':
      case 'dueno':
        return Permiso.values.toSet();
      case 'admin':
        return Permiso.values.toSet()..remove(Permiso.permisosAdministrar);
      default:
        return {
          Permiso.dashboardVer,
          Permiso.insumosVer,
          Permiso.catalogoVer,
          Permiso.ventasVer,
          Permiso.ventasHistorial,
          Permiso.equiposConfigurar,
          Permiso.turnosPropios,
        };
    }
  }

  /// El dueño y el superadmin no pueden perder permisos.
  static bool esRolIntocable(String rol) =>
      rol == 'superadmin' || rol == 'dueño' || rol == 'dueno';

  static String etiquetaRol(String rol) {
    switch (rol) {
      case 'superadmin':
        return 'Superadmin';
      case 'dueño':
      case 'dueno':
        return 'Dueño';
      case 'admin':
        return 'Administrador';
      case 'empleado':
        return 'Empleado';
      default:
        return rol;
    }
  }
}
