import '../../core/permissions/permiso.dart';

/// Rol creado por el dueño del negocio (socio, reportes, supervisor...).
/// En `profiles.rol` se guarda su [clave].
class RolPersonalizado {
  final String id;
  final String tenantId;
  final String clave;
  final String nombre;
  final String? descripcion;
  final Set<Permiso> permisos;

  const RolPersonalizado({
    required this.id,
    required this.tenantId,
    required this.clave,
    required this.nombre,
    required this.permisos,
    this.descripcion,
  });

  RolPersonalizado copyWith({String? nombre, String? descripcion, Set<Permiso>? permisos}) =>
      RolPersonalizado(
        id: id,
        tenantId: tenantId,
        clave: clave,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        permisos: permisos ?? this.permisos,
      );

  factory RolPersonalizado.fromJson(Map<String, dynamic> json) {
    final claves = (json['permisos'] as List? ?? const []).map((e) => e.toString());
    return RolPersonalizado(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      clave: json['clave'] as String,
      nombre: json['nombre'] as String? ?? json['clave'] as String,
      descripcion: json['descripcion'] as String?,
      permisos: {
        for (final c in claves)
          if (Permiso.deClave(c) != null) Permiso.deClave(c)!,
      },
    );
  }

  static List<String> clavesDe(Set<Permiso> permisos) =>
      (permisos.map((p) => p.clave).toList()..sort());
}
