enum EstadoTurno { sinEntrada, trabajando, enComida, finalizado }

/// Registro de un turno: entrada, comida y salida.
class Asistencia {
  final String id;
  final String userId;
  final String? tenantId;
  final DateTime fecha; // día del turno (solo fecha)
  final DateTime? entrada;
  final DateTime? comidaInicio;
  final DateTime? comidaFin;
  final DateTime? salida;
  final int retardoMinutos;
  final String? notas;

  const Asistencia({
    required this.id,
    required this.userId,
    required this.fecha,
    this.tenantId,
    this.entrada,
    this.comidaInicio,
    this.comidaFin,
    this.salida,
    this.retardoMinutos = 0,
    this.notas,
  });

  EstadoTurno get estado {
    if (entrada == null) return EstadoTurno.sinEntrada;
    if (salida != null) return EstadoTurno.finalizado;
    if (comidaInicio != null && comidaFin == null) return EstadoTurno.enComida;
    return EstadoTurno.trabajando;
  }

  bool get abierto => entrada != null && salida == null;

  /// Tiempo de comida (en curso o terminada).
  Duration comida([DateTime? ahora]) {
    if (comidaInicio == null) return Duration.zero;
    final fin = comidaFin ?? salida ?? (ahora ?? DateTime.now());
    final d = fin.difference(comidaInicio!);
    return d.isNegative ? Duration.zero : d;
  }

  /// Tiempo trabajado sin contar la comida.
  Duration trabajado([DateTime? ahora]) {
    if (entrada == null) return Duration.zero;
    final fin = salida ?? (ahora ?? DateTime.now());
    final total = fin.difference(entrada!) - comida(ahora);
    return total.isNegative ? Duration.zero : total;
  }

  Asistencia copyWith({
    DateTime? entrada,
    DateTime? comidaInicio,
    DateTime? comidaFin,
    DateTime? salida,
    int? retardoMinutos,
    String? notas,
    bool limpiarEntrada = false,
    bool limpiarComidaInicio = false,
    bool limpiarComidaFin = false,
    bool limpiarSalida = false,
  }) {
    return Asistencia(
      id: id,
      userId: userId,
      tenantId: tenantId,
      fecha: fecha,
      entrada: limpiarEntrada ? null : (entrada ?? this.entrada),
      comidaInicio: limpiarComidaInicio ? null : (comidaInicio ?? this.comidaInicio),
      comidaFin: limpiarComidaFin ? null : (comidaFin ?? this.comidaFin),
      salida: limpiarSalida ? null : (salida ?? this.salida),
      retardoMinutos: retardoMinutos ?? this.retardoMinutos,
      notas: notas ?? this.notas,
    );
  }

  static DateTime? _ts(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory Asistencia.fromJson(Map<String, dynamic> json) {
    final f = DateTime.parse(json['fecha'] as String);
    return Asistencia(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String?,
      fecha: DateTime(f.year, f.month, f.day),
      entrada: _ts(json['entrada']),
      comidaInicio: _ts(json['comida_inicio']),
      comidaFin: _ts(json['comida_fin']),
      salida: _ts(json['salida']),
      retardoMinutos: (json['retardo_minutos'] as num?)?.toInt() ?? 0,
      notas: json['notas'] as String?,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'entrada': entrada?.toUtc().toIso8601String(),
        'comida_inicio': comidaInicio?.toUtc().toIso8601String(),
        'comida_fin': comidaFin?.toUtc().toIso8601String(),
        'salida': salida?.toUtc().toIso8601String(),
        'retardo_minutos': retardoMinutos,
        'notas': notas,
      };
}

/// Datos mínimos de un integrante del equipo.
class EmpleadoResumen {
  final String id;
  final String nombre;
  final String rol;
  final String avatarStyle;
  final String? avatarSeed;
  final String? avatarPng;

  const EmpleadoResumen({
    required this.id,
    required this.nombre,
    required this.rol,
    this.avatarStyle = 'gradiente',
    this.avatarSeed,
    this.avatarPng,
  });
}
