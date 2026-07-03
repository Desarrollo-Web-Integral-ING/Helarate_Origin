class UsuarioPerfil {
  final String id;
  final String nombre;
  final String rol; // 'dueño' o 'empleado'
  final DateTime createdAt;

  UsuarioPerfil({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.createdAt,
  });

  bool get isOwner => rol == 'dueño';
  bool get isEmployee => rol == 'empleado';

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'rol': rol,
        'created_at': createdAt.toIso8601String(),
      };

  factory UsuarioPerfil.fromJson(Map<String, dynamic> json) {
    return UsuarioPerfil(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Usuario Nuevo',
      rol: json['rol'] as String? ?? 'empleado',
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
