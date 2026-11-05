/// Horario de un empleado para un día de la semana (ISO: 1 = lunes ... 7 = domingo).
class HorarioEmpleado {
  final String? id;
  final String userId;
  final int diaSemana;
  final String horaEntrada; // 'HH:mm'
  final String horaSalida; // 'HH:mm'
  final int comidaMinutos;
  final bool activo;

  const HorarioEmpleado({
    required this.userId,
    required this.diaSemana,
    this.id,
    this.horaEntrada = '09:00',
    this.horaSalida = '18:00',
    this.comidaMinutos = 30,
    this.activo = true,
  });

  HorarioEmpleado copyWith({
    String? horaEntrada,
    String? horaSalida,
    int? comidaMinutos,
    bool? activo,
  }) {
    return HorarioEmpleado(
      id: id,
      userId: userId,
      diaSemana: diaSemana,
      horaEntrada: horaEntrada ?? this.horaEntrada,
      horaSalida: horaSalida ?? this.horaSalida,
      comidaMinutos: comidaMinutos ?? this.comidaMinutos,
      activo: activo ?? this.activo,
    );
  }

  static String _hhmm(dynamic v) {
    final s = (v as String? ?? '00:00');
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  factory HorarioEmpleado.fromJson(Map<String, dynamic> json) => HorarioEmpleado(
        id: json['id'] as String?,
        userId: json['user_id'] as String,
        diaSemana: (json['dia_semana'] as num).toInt(),
        horaEntrada: _hhmm(json['hora_entrada']),
        horaSalida: _hhmm(json['hora_salida']),
        comidaMinutos: (json['comida_minutos'] as num?)?.toInt() ?? 30,
        activo: json['activo'] as bool? ?? true,
      );

  Map<String, dynamic> toJson(String tenantId) => {
        'tenant_id': tenantId,
        'user_id': userId,
        'dia_semana': diaSemana,
        'hora_entrada': horaEntrada,
        'hora_salida': horaSalida,
        'comida_minutos': comidaMinutos,
        'activo': activo,
      };

  /// Hora de entrada de este horario en el día [dia].
  DateTime entradaEn(DateTime dia) => _enDia(dia, horaEntrada);

  DateTime salidaEn(DateTime dia) => _enDia(dia, horaSalida);

  static DateTime _enDia(DateTime dia, String hhmm) {
    final p = hhmm.split(':');
    return DateTime(dia.year, dia.month, dia.day, int.parse(p[0]), int.parse(p[1]));
  }

  static const List<String> nombresDias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  String get nombreDia => nombresDias[diaSemana - 1];
}
