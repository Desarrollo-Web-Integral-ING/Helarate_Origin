class ProductoProduccion {
  final String id;
  String nombre;
  String unidad;
  double cantidad;
  double cantidadMinima;
  double precioUnitario;
  String categoria;
  String? imagenPath;
  DateTime ultimaActualizacion;

  ProductoProduccion({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.cantidad,
    this.cantidadMinima = 0,
    required this.precioUnitario,
    required this.categoria,
    this.imagenPath,
    required this.ultimaActualizacion,
  });

  bool get stockBajo => cantidadMinima > 0 && cantidad <= cantidadMinima;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'unidad': unidad,
        'cantidad': cantidad,
        'cantidadMinima': cantidadMinima,
        'precioUnitario': precioUnitario,
        'categoria': categoria,
        'imagenPath': imagenPath,
        'ultimaActualizacion': ultimaActualizacion.toIso8601String(),
      };

  factory ProductoProduccion.fromJson(Map<String, dynamic> json) =>
      ProductoProduccion(
        id: json['id'],
        nombre: json['nombre'],
        unidad: json['unidad'],
        cantidad: (json['cantidad'] as num).toDouble(),
        cantidadMinima: (json['cantidadMinima'] as num? ?? 0).toDouble(),
        precioUnitario: (json['precioUnitario'] as num).toDouble(),
        categoria: json['categoria'],
        imagenPath: json['imagenPath'],
        ultimaActualizacion: DateTime.parse(json['ultimaActualizacion']),
      );

  double get valorTotal => cantidad * precioUnitario;
}
