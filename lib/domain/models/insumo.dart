enum TipoInsumo {
  materiaPrima,
  productoVenta,
}

class Insumo {
  final String id;
  final String nombre;
  final String unidad;
  final double costoUnitario;
  final double stockActual;
  final double stockMinimo;
  final TipoInsumo tipo;
  final double precioVenta;
  final String? userId;
  final DateTime updatedAt;

  Insumo({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.costoUnitario,
    required this.stockActual,
    required this.stockMinimo,
    required this.tipo,
    required this.precioVenta,
    this.userId,
    required this.updatedAt,
  });

  bool get stockBajo => stockMinimo > 0 && stockActual <= stockMinimo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'unidad': unidad,
        'costo_unitario': costoUnitario,
        'stock_actual': stockActual,
        'stock_minimo': stockMinimo,
        'tipo': tipo == TipoInsumo.materiaPrima ? 'Materia Prima' : 'Producto de Venta',
        'precio_venta': precioVenta,
        'user_id': userId,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Insumo.fromJson(Map<String, dynamic> json) {
    final tipoStr = json['tipo'] as String;
    final tipoVal = tipoStr == 'Producto de Venta'
        ? TipoInsumo.productoVenta
        : TipoInsumo.materiaPrima;

    return Insumo(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      unidad: json['unidad'] as String,
      costoUnitario: (json['costo_unitario'] as num).toDouble(),
      stockActual: (json['stock_actual'] as num).toDouble(),
      stockMinimo: (json['stock_minimo'] as num).toDouble(),
      tipo: tipoVal,
      precioVenta: (json['precio_venta'] as num).toDouble(),
      userId: json['user_id'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
