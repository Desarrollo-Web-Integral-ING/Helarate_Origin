import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/venta_model.dart';
import '../../domain/repositories/venta_repository.dart';


class SupabaseVentaRepository implements VentaRepository {
  final _client = Supabase.instance.client;

  @override
  Future<void> create(VentaModel venta) async {
    final userId = _client.auth.currentUser?.id;

    final headerData = venta.toJson();
    headerData['user_id'] = userId;
    
    headerData.remove('ganancia_neta');

    await _client.from('ventas').insert(headerData);

    if (venta.detalles.isNotEmpty) {
      final detailsData = venta.detalles.map((d) => d.toJson()).toList();
      await _client.from('detalle_venta').insert(detailsData);
    }
  }

  @override
  Future<List<VentaModel>> getByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return getByDateRange(startOfDay, endOfDay);
  }

  @override
  Future<List<VentaModel>> getByDateRange(DateTime start, DateTime end) async {
    final userId   = _client.auth.currentUser?.id;
    final startStr = start.toIso8601String().substring(0, 10); // 'YYYY-MM-DD'
    final endStr   = end.toIso8601String().substring(0, 10);

    final response = await _client
        .from('ventas')
        .select('*, detalle_venta(*, insumos(nombre))')
        .eq('user_id', userId!)
        .gte('fecha', startStr)
        .lte('fecha', endStr)
        .order('fecha', ascending: false);

    return (response as List)
        .map((json) => VentaModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('ventas').delete().eq('id', id);
  }

  @override
  Future<Map<String, double>> getTodaySummary() async {
    final todayVentas = await getByDate(DateTime.now());

    double totalIngresos = 0.0;
    double totalCostos   = 0.0;
    double gananciaNeta  = 0.0;

    for (final v in todayVentas) {
      totalIngresos += v.totalIngresos;
      totalCostos   += v.totalCostos;
      gananciaNeta  += v.gananciaNeta;
    }

    return {
      'total_ingresos': totalIngresos,
      'total_costos':   totalCostos,
      'ganancia_neta':  gananciaNeta,
    };
  }
}