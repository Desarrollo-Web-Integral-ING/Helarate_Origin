class Venta {
  final String id;
  final String productoId;
  final String productoNombre;
  final int cantidad;
  final double precioUnitario;
  final DateTime fecha;
  String? nota;

  Venta({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.fecha,
    this.nota,
  });

  double get total => cantidad * precioUnitario;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productoId': productoId,
        'productoNombre': productoNombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'fecha': fecha.toIso8601String(),
        'nota': nota,
      };

  factory Venta.fromJson(Map<String, dynamic> json) => Venta(
        id: json['id'],
        productoId: json['productoId'],
        productoNombre: json['productoNombre'],
        cantidad: json['cantidad'],
        precioUnitario: (json['precioUnitario'] as num).toDouble(),
        fecha: DateTime.parse(json['fecha']),
        nota: json['nota'],
      );
}
