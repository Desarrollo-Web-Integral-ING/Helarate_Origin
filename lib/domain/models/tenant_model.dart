class TenantModel {
  final String id;
  final String nombre;
  final String tipoNegocio;
  final String colorPrimario;
  final String? logoUrl;
  final String logoIcon; // Ej. 'storefront', 'restaurant', 'coffee', 'shopping_bag', 'icecream', 'fitness_center'
  final String moneda;
  final String? direccion;
  final String? telefono;
  final String? mensajeRecibo;
  final bool activo;
  final bool modoOscuro;
  final DateTime? fechaVencimiento;

  TenantModel({
    required this.id,
    required this.nombre,
    this.tipoNegocio = 'General',
    this.colorPrimario = '#2563EB',
    this.logoUrl,
    this.logoIcon = 'storefront',
    this.moneda = '\$',
    this.direccion,
    this.telefono,
    this.mensajeRecibo = '¡Gracias por su compra!',
    this.activo = true,
    this.modoOscuro = false,
    this.fechaVencimiento,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? 'Mi Negocio',
      tipoNegocio: json['tipo_negocio'] as String? ?? 'General',
      colorPrimario: json['color_primario'] as String? ?? '#2563EB',
      logoUrl: json['logo_url'] as String?,
      logoIcon: json['logo_icon'] as String? ?? 'storefront',
      moneda: json['moneda'] as String? ?? '\$',
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      mensajeRecibo: json['mensaje_recibo'] as String? ?? '¡Gracias por su compra!',
      activo: json['activo'] as bool? ?? true,
      modoOscuro: json['modo_oscuro'] as bool? ?? false,
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.tryParse(json['fecha_vencimiento'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo_negocio': tipoNegocio,
        'color_primario': colorPrimario,
        'logo_url': logoUrl,
        'logo_icon': logoIcon,
        'moneda': moneda,
        'direccion': direccion,
        'telefono': telefono,
        'mensaje_recibo': mensajeRecibo,
        'activo': activo,
        'modo_oscuro': modoOscuro,
        'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      };

  TenantModel copyWith({
    String? nombre,
    String? tipoNegocio,
    String? colorPrimario,
    String? logoUrl,
    String? logoIcon,
    String? moneda,
    String? direccion,
    String? telefono,
    String? mensajeRecibo,
    bool? activo,
    bool? modoOscuro,
    DateTime? fechaVencimiento,
  }) {
    return TenantModel(
      id: id,
      nombre: nombre ?? this.nombre,
      tipoNegocio: tipoNegocio ?? this.tipoNegocio,
      colorPrimario: colorPrimario ?? this.colorPrimario,
      logoUrl: logoUrl ?? this.logoUrl,
      logoIcon: logoIcon ?? this.logoIcon,
      moneda: moneda ?? this.moneda,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      mensajeRecibo: mensajeRecibo ?? this.mensajeRecibo,
      activo: activo ?? this.activo,
      modoOscuro: modoOscuro ?? this.modoOscuro,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
    );
  }
}
