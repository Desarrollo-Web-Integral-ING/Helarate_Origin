class GastoModel {
  final String id;
  final String? insumoId;
  final String? insumoNombre; // Helper virtual field
  final DateTime fecha;
  final double cantidadUsada;
  final double costoTotal;
  final String? descripcion;
  final String? userId;

  GastoModel({
    required this.id,
    this.insumoId,
    this.insumoNombre,
    required this.fecha,
    required this.cantidadUsada,
    required this.costoTotal,
    this.descripcion,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'insumo_id': insumoId,
        'fecha': fecha.toIso8601String(),
        'cantidad_usada': cantidadUsada,
        'costo_total': costoTotal,
        'descripcion': descripcion,
        'user_id': userId,
      };

  factory GastoModel.fromJson(Map<String, dynamic> json) => GastoModel(
        id: json['id'] as String,
        insumoId: json['insumo_id'] as String?,
        // Se puede rellenar desde un JOIN en la consulta si se solicita
        insumoNombre: json['insumos'] != null ? json['insumos']['nombre'] as String? : null,
        fecha: DateTime.parse(json['fecha'] as String),
        cantidadUsada: (json['cantidad_usada'] as num).toDouble(),
        costoTotal: (json['costo_total'] as num).toDouble(),
        descripcion: json['descripcion'] as String?,
        userId: json['user_id'] as String?,
      );
}
