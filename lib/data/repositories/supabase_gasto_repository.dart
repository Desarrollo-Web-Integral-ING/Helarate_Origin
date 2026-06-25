import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/gasto_model.dart';
import '../../domain/repositories/gasto_repository.dart';

// Pattern: Repository
class SupabaseGastoRepository implements GastoRepository {
  final _client = Supabase.instance.client;

  @override
  Future<void> create(GastoModel gasto) async {
    final data = gasto.toJson();
    await _client.from('gastos_operativos').insert(data);
  }

  @override
  Future<List<GastoModel>> getByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc().toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();

    final response = await _client
        .from('gastos_operativos')
        .select('*, insumos(nombre)')
        .gte('fecha', startOfDay)
        .lte('fecha', endOfDay)
        .order('fecha', ascending: false);

    return (response as List).map((json) => GastoModel.fromJson(json)).toList();
  }
}
