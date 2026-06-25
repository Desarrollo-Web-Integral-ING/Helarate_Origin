import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/producto_produccion.dart';
import '../../domain/models/producto_venta.dart';
import '../../domain/models/venta.dart';

class StorageService {
  static const _keyProduccion = 'productos_produccion';
  static const _keyVenta = 'productos_venta';
  static const _keyVentas = 'ventas';
  static const _keyInited = 'datos_inicializados';

  static final _uuid = Uuid();

  Future<void> inicializarDatosDefecto() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyInited) == true) return;

    final now = DateTime.now();

    // ── Insumos por defecto ──────────────────────────────────────────────
    final insumos = [
      // Plásticos
      _insumo('Bolsa 25x35', 'paquete', 'Plásticos', now),
      _insumo('Bolsa 40x60', 'paquete', 'Plásticos', now),
      // Vasos térmicos
      _insumo('Vaso térmico 16 oz', 'pzs', 'Vasos térmicos', now),
      _insumo('Vaso térmico 32 oz', 'pzs', 'Vasos térmicos', now),
      // Tapas y vasos
      _insumo('Tapa para vaso térmico', 'pzs', 'Tapas y vasos', now),
      _insumo('Vaso #5', 'pzs', 'Tapas y vasos', now),
      _insumo('Vaso #5 1/2', 'pzs', 'Tapas y vasos', now),
      // Cubiertos
      _insumo('Cuchara nevera', 'pzs', 'Cubiertos', now),
      // Servilletas
      _insumo('Servilletas', 'paquete', 'Servilletas', now),
      // Barquillos y conos
      _insumo('Barquillo', 'pzs', 'Barquillos y conos', now),
      _insumo('Mikicono', 'pzs', 'Barquillos y conos', now),
      _insumo('Cono de galleta', 'pzs', 'Barquillos y conos', now),
    ];

    // ── Sabores de nieve por defecto ─────────────────────────────────────
    final nieves = [
      'Mantecado', 'Nuez', 'Beso de Ángel', 'Piña', 'Mamey',
      'Zapote', 'Limón', 'Galleta', 'Chocolate', 'Garambullo', 'Guayaba',
    ].map((sabor) => ProductoVenta(
          id: _uuid.v4(),
          nombre: 'Nieve $sabor',
          sabor: sabor,
          tamano: '',
          precio: 0,
          stockActual: 0,
          stockMinimo: 1,
          categoria: 'Litro',
          ultimaActualizacion: now,
        )).toList();

    await saveProductosProduccion(insumos);
    await saveProductosVenta(nieves);
    await prefs.setBool(_keyInited, true);
  }

  static ProductoProduccion _insumo(
      String nombre, String unidad, String categoria, DateTime now) =>
      ProductoProduccion(
        id: _uuid.v4(),
        nombre: nombre,
        unidad: unidad,
        cantidad: 0,
        cantidadMinima: 0,
        precioUnitario: 0,
        categoria: categoria,
        ultimaActualizacion: now,
      );

  // ── Productos de Producción ──────────────────────────────────────────────
  Future<List<ProductoProduccion>> getProductosProduccion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProduccion);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => ProductoProduccion.fromJson(e)).toList();
  }

  Future<void> saveProductosProduccion(List<ProductoProduccion> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProduccion, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> addProductoProduccion(ProductoProduccion p) async {
    final list = await getProductosProduccion();
    list.add(p);
    await saveProductosProduccion(list);
  }

  Future<void> updateProductoProduccion(ProductoProduccion p) async {
    final list = await getProductosProduccion();
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx != -1) list[idx] = p;
    await saveProductosProduccion(list);
  }

  Future<void> deleteProductoProduccion(String id) async {
    final list = await getProductosProduccion();
    list.removeWhere((e) => e.id == id);
    await saveProductosProduccion(list);
  }

  // ── Productos de Venta ───────────────────────────────────────────────────
  Future<List<ProductoVenta>> getProductosVenta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyVenta);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => ProductoVenta.fromJson(e)).toList();
  }

  Future<void> saveProductosVenta(List<ProductoVenta> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVenta, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> addProductoVenta(ProductoVenta p) async {
    final list = await getProductosVenta();
    list.add(p);
    await saveProductosVenta(list);
  }

  Future<void> updateProductoVenta(ProductoVenta p) async {
    final list = await getProductosVenta();
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx != -1) list[idx] = p;
    await saveProductosVenta(list);
  }

  Future<void> deleteProductoVenta(String id) async {
    final list = await getProductosVenta();
    list.removeWhere((e) => e.id == id);
    await saveProductosVenta(list);
  }

  // ── Ventas ───────────────────────────────────────────────────────────────
  Future<List<Venta>> getVentas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyVentas);
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.map((e) => Venta.fromJson(e)).toList();
  }

  Future<void> saveVentas(List<Venta> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVentas, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> addVenta(Venta v) async {
    final list = await getVentas();
    list.add(v);
    await saveVentas(list);
  }

  Future<void> deleteVenta(String id) async {
    final list = await getVentas();
    list.removeWhere((e) => e.id == id);
    await saveVentas(list);
  }
}
