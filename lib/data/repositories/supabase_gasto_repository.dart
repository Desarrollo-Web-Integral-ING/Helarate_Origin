import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/gasto_model.dart';
import '../../domain/repositories/gasto_repository.dart';


class SupabaseGastoRepository implements GastoRepository {
  final _client = Supabase.instance.client;

  @override
  Future<void> create(GastoModel gasto) async {
    final userId = _client.auth.currentUser?.id;

    final data = gasto.toJson();
    data['user_id'] = userId;

    await _client.from('gastos_operativos').insert(data);
  }

  @override
  Future<List<GastoModel>> getByDate(DateTime date) async {
    final userId   = _client.auth.currentUser?.id;
    final dateStr  = date.toIso8601String().substring(0, 10); // 'YYYY-MM-DD'

    final response = await _client
        .from('gastos_operativos')
        .select('*, insumos(nombre)')
        .eq('user_id', userId!)
        .eq('fecha', dateStr)
        .order('fecha', ascending: false);

    return (response as List)
        .map((json) => GastoModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}