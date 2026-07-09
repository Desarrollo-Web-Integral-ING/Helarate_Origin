class UsuarioPerfil {
  final String id;
  final String nombre;
  final String rol; // 'dueño' o 'empleado'
  final String email;
  final DateTime createdAt;
  final DateTime? aceptadoAvisoAt;

  UsuarioPerfil({
    required this.id,
    required this.nombre,
    required this.rol,
    this.email = '',
    required this.createdAt,
    this.aceptadoAvisoAt,
  });

  bool get isOwner => rol == 'dueño';
  bool get isEmployee => rol == 'empleado';

  UsuarioPerfil copyWith({
    String? nombre,
    String? rol,
    String? email,
  }) {
    return UsuarioPerfil(
      id: id,
      nombre: nombre ?? this.nombre,
      rol: rol ?? this.rol,
      email: email ?? this.email,
      createdAt: createdAt,
      aceptadoAvisoAt: aceptadoAvisoAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'rol': rol,
        'email': email,
        'created_at': createdAt.toIso8601String(),
        'aceptado_aviso_at': aceptadoAvisoAt?.toIso8601String(),
      };

  factory UsuarioPerfil.fromJson(Map<String, dynamic> json) {
    return UsuarioPerfil(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Usuario Nuevo',
      rol: json['rol'] as String? ?? 'empleado',
      email: json['email'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      aceptadoAvisoAt: json['aceptado_aviso_at'] != null 
          ? DateTime.parse(json['aceptado_aviso_at'] as String) 
          : null,
    );
  }
}
