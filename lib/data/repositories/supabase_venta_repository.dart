import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/venta_model.dart';
import '../../domain/repositories/venta_repository.dart';

// Pattern: Repository
class SupabaseVentaRepository implements VentaRepository {
  final _client = Supabase.instance.client;

  @override
  Future<void> create(VentaModel venta) async {
    // 1. Insertar cabecera de la venta
    final headerData = venta.toJson();
    await _client.from('ventas').insert(headerData);

    // 2. Insertar detalles de la venta (si existen)
    if (venta.detalles.isNotEmpty) {
      final detailsData = venta.detalles.map((d) => d.toJson()).toList();
      await _client.from('detalle_venta').insert(detailsData);
    }
  }

  @override
  Future<List<VentaModel>> getByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc().toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();

    final response = await _client
        .from('ventas')
        .select('*, detalle_venta(*, insumos(nombre))')
        .gte('fecha', startOfDay)
        .lte('fecha', endOfDay)
        .order('fecha', ascending: false);

    return (response as List).map((json) => VentaModel.fromJson(json)).toList();
  }

  @override
  Future<Map<String, double>> getTodaySummary() async {
    final todayVentas = await getByDate(DateTime.now());
    double totalIngresos = 0.0;
    double totalCostos = 0.0;
    double gananciaNeta = 0.0;

    for (var v in todayVentas) {
      totalIngresos += v.totalIngresos;
      totalCostos += v.totalCostos;
      gananciaNeta += v.gananciaNeta;
    }

    return {
      'total_ingresos': totalIngresos,
      'total_costos': totalCostos,
      'ganancia_neta': gananciaNeta,
    };
  }
}
