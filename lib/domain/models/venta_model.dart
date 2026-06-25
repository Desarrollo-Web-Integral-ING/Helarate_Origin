class VentaModel {
  final String id;
  final DateTime fecha;
  final double totalIngresos;
  final double totalCostos;
  final double gananciaNeta;
  final String? userId;
  final List<DetalleVentaModel> detalles;

  VentaModel({
    required this.id,
    required this.fecha,
    required this.totalIngresos,
    required this.totalCostos,
    required this.gananciaNeta,
    this.userId,
    this.detalles = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'total_ingresos': totalIngresos,
        'total_costos': totalCostos,
        'ganancia_neta': gananciaNeta,
        'user_id': userId,
      };

  factory VentaModel.fromJson(Map<String, dynamic> json) {
    final listDetalles = json['detalle_venta'] as List?;
    final detallesList = listDetalles != null
        ? listDetalles.map((d) => DetalleVentaModel.fromJson(d)).toList()
        : <DetalleVentaModel>[];

    return VentaModel(
      id: json['id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      totalIngresos: (json['total_ingresos'] as num).toDouble(),
      totalCostos: (json['total_costos'] as num).toDouble(),
      gananciaNeta: (json['ganancia_neta'] as num).toDouble(),
      userId: json['user_id'] as String?,
      detalles: detallesList,
    );
  }
}

class DetalleVentaModel {
  final String id;
  final String ventaId;
  final String insumoId;
  final String? insumoNombre; // Helper virtual field
  final double cantidad;
  final double precioVentaUnitario;
  final double costoUnitario;

  DetalleVentaModel({
    required this.id,
    required this.ventaId,
    required this.insumoId,
    this.insumoNombre,
    required this.cantidad,
    required this.precioVentaUnitario,
    required this.costoUnitario,
  });

  double get total => cantidad * precioVentaUnitario;
  double get costoTotal => cantidad * costoUnitario;

  Map<String, dynamic> toJson() => {
        'id': id,
        'venta_id': ventaId,
        'insumo_id': insumoId,
        'cantidad': cantidad,
        'precio_venta_unitario': precioVentaUnitario,
        'costo_unitario': costoUnitario,
      };

  factory DetalleVentaModel.fromJson(Map<String, dynamic> json) => DetalleVentaModel(
        id: json['id'] as String,
        ventaId: json['venta_id'] as String,
        insumoId: json['insumo_id'] as String,
        insumoNombre: json['insumos'] != null ? json['insumos']['nombre'] as String? : null,
        cantidad: (json['cantidad'] as num).toDouble(),
        precioVentaUnitario: (json['precio_venta_unitario'] as num).toDouble(),
        costoUnitario: (json['costo_unitario'] as num).toDouble(),
      );
}
