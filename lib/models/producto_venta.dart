class ProductoVenta {
  final String id;
  String nombre;
  String sabor;
  String tamano;
  double precio;
  int stockActual;
  int stockMinimo;
  String categoria;
  String? imagenPath;
  DateTime ultimaActualizacion;

  ProductoVenta({
    required this.id,
    required this.nombre,
    required this.sabor,
    required this.tamano,
    required this.precio,
    required this.stockActual,
    required this.stockMinimo,
    required this.categoria,
    this.imagenPath,
    required this.ultimaActualizacion,
  });

  bool get stockBajo => stockActual <= stockMinimo && stockActual > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'sabor': sabor,
        'tamano': tamano,
        'precio': precio,
        'stockActual': stockActual,
        'stockMinimo': stockMinimo,
        'categoria': categoria,
        'imagenPath': imagenPath,
        'ultimaActualizacion': ultimaActualizacion.toIso8601String(),
      };

  factory ProductoVenta.fromJson(Map<String, dynamic> json) => ProductoVenta(
        id: json['id'],
        nombre: json['nombre'],
        sabor: json['sabor'] ?? '',
        tamano: json['tamano'] ?? '',
        precio: (json['precio'] as num).toDouble(),
        stockActual: json['stockActual'],
        stockMinimo: json['stockMinimo'],
        categoria: json['categoria'],
        imagenPath: json['imagenPath'],
        ultimaActualizacion: DateTime.parse(json['ultimaActualizacion']),
      );
}
