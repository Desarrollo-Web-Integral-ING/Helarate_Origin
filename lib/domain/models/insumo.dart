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
  final String categoria;
  final String? sabor;
  final String? tamano;
  final String? userId;
  final DateTime updatedAt;
  final String? imagenPath;

  Insumo({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.costoUnitario,
    required this.stockActual,
    required this.stockMinimo,
    required this.tipo,
    required this.precioVenta,
    required this.categoria,
    this.sabor,
    this.tamano,
    this.userId,
    required this.updatedAt,
    this.imagenPath,
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
        'categoria': categoria,
        'sabor': sabor,
        'tamano': tamano,
        'user_id': userId,
        'updated_at': updatedAt.toIso8601String(),
        'imagen_path': imagenPath,
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
      categoria: json['categoria'] as String? ?? 'General',
      sabor: json['sabor'] as String?,
      tamano: json['tamano'] as String?,
      userId: json['user_id'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      imagenPath: json['imagen_path'] as String?,
    );
  }
}
