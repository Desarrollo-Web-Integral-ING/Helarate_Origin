import 'dart:convert';

enum TipoDatoCampo {
  texto,
  numero,
  fecha,
  opciones,
}

class CampoPersonalizado {
  final String id;
  final String tenantId;
  final String nombre;
  final TipoDatoCampo tipoDato;
  final List<String> opciones;
  final bool obligatorio;
  final String aplicaA; // 'todos', 'materia_prima', 'producto_venta'
  final int orden;
  final DateTime createdAt;

  CampoPersonalizado({
    required this.id,
    required this.tenantId,
    required this.nombre,
    required this.tipoDato,
    this.opciones = const [],
    this.obligatorio = false,
    this.aplicaA = 'todos',
    this.orden = 0,
    required this.createdAt,
  });

  CampoPersonalizado copyWith({
    String? id,
    String? tenantId,
    String? nombre,
    TipoDatoCampo? tipoDato,
    List<String>? opciones,
    bool? obligatorio,
    String? aplicaA,
    int? orden,
    DateTime? createdAt,
  }) {
    return CampoPersonalizado(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      nombre: nombre ?? this.nombre,
      tipoDato: tipoDato ?? this.tipoDato,
      opciones: opciones ?? this.opciones,
      obligatorio: obligatorio ?? this.obligatorio,
      aplicaA: aplicaA ?? this.aplicaA,
      orden: orden ?? this.orden,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'nombre': nombre,
        'tipo_dato': tipoDato.name,
        'opciones': opciones,
        'obligatorio': obligatorio,
        'aplica_a': aplicaA,
        'orden': orden,
        'created_at': createdAt.toIso8601String(),
      };

  factory CampoPersonalizado.fromJson(Map<String, dynamic> json) {
    TipoDatoCampo tipo = TipoDatoCampo.texto;
    final tipoStr = json['tipo_dato'] as String? ?? 'texto';
    for (final t in TipoDatoCampo.values) {
      if (t.name == tipoStr) {
        tipo = t;
        break;
      }
    }

    List<String> ops = [];
    if (json['opciones'] != null) {
      if (json['opciones'] is List) {
        ops = (json['opciones'] as List).map((e) => e.toString()).toList();
      } else if (json['opciones'] is String) {
        try {
          final decoded = jsonDecode(json['opciones'] as String);
          if (decoded is List) ops = decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
    }

    return CampoPersonalizado(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      tipoDato: tipo,
      opciones: ops,
      obligatorio: json['obligatorio'] as bool? ?? false,
      aplicaA: json['aplica_a'] as String? ?? 'todos',
      orden: json['orden'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
