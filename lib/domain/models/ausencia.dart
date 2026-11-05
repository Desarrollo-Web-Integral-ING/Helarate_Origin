enum TipoAusencia {
  vacaciones('vacaciones', 'Vacaciones'),
  diaLibre('dia_libre', 'Día libre'),
  permiso('permiso', 'Permiso'),
  incapacidad('incapacidad', 'Incapacidad'),
  festivo('festivo', 'Festivo / cierre');

  final String valor;
  final String etiqueta;
  const TipoAusencia(this.valor, this.etiqueta);

  static TipoAusencia deValor(String? v) => TipoAusencia.values.firstWhere(
        (t) => t.valor == v,
        orElse: () => TipoAusencia.diaLibre,
      );
}

/// Periodo en que una persona (o todo el negocio) no trabaja.
class Ausencia {
  final String id;
  final String? tenantId;

  /// null = aplica a todo el negocio (festivo, cierre).
  final String? userId;
  final TipoAusencia tipo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? notas;

  const Ausencia({
    required this.id,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
    this.tenantId,
    this.userId,
    this.notas,
  });

  bool get paraTodos => userId == null;

  /// Cantidad de días naturales que abarca.
  int get dias => fechaFin.difference(fechaInicio).inDays + 1;

  bool cubre(DateTime d) {
    final dia = DateTime(d.year, d.month, d.day);
    return !dia.isBefore(fechaInicio) && !dia.isAfter(fechaFin);
  }

  static DateTime _fecha(String s) {
    final d = DateTime.parse(s);
    return DateTime(d.year, d.month, d.day);
  }

  factory Ausencia.fromJson(Map<String, dynamic> json) => Ausencia(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String?,
        userId: json['user_id'] as String?,
        tipo: TipoAusencia.deValor(json['tipo'] as String?),
        fechaInicio: _fecha(json['fecha_inicio'] as String),
        fechaFin: _fecha(json['fecha_fin'] as String),
        notas: json['notas'] as String?,
      );
}

/// Reglas de turnos del negocio.
class TurnosConfig {
  /// Minutos de tolerancia antes de contar un retardo.
  final int toleranciaRetardoMin;

  /// Minutos de comida que se proponen al crear un horario.
  final int comidaMinutosDefault;

  const TurnosConfig({this.toleranciaRetardoMin = 10, this.comidaMinutosDefault = 30});

  TurnosConfig copyWith({int? toleranciaRetardoMin, int? comidaMinutosDefault}) => TurnosConfig(
        toleranciaRetardoMin: toleranciaRetardoMin ?? this.toleranciaRetardoMin,
        comidaMinutosDefault: comidaMinutosDefault ?? this.comidaMinutosDefault,
      );

  factory TurnosConfig.fromJson(Map<String, dynamic> json) => TurnosConfig(
        toleranciaRetardoMin: (json['tolerancia_retardo_min'] as num?)?.toInt() ?? 10,
        comidaMinutosDefault: (json['comida_minutos_default'] as num?)?.toInt() ?? 30,
      );
}
