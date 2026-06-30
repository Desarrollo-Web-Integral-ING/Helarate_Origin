import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/insumo.dart';
import '../../domain/repositories/insumo_repository.dart';


class SupabaseInsumoRepository implements InsumoRepository {
  final _client = Supabase.instance.client;

  @override
  Future<List<Insumo>> getAll() async {
    final userId = _client.auth.currentUser?.id;
    var query = _client.from('insumos').select();
    if (userId != null) {
      query = query.eq('user_id', userId);
    }
    
    final response = await query.order('nombre', ascending: true);
    return (response as List)
        .map((json) => Insumo.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create(Insumo insumo) async {
    final userId = _client.auth.currentUser?.id;

    final data = insumo.toJson();
    data['user_id'] = userId;

    await _client.from('insumos').insert(data);
  }

  @override
  Future<void> update(Insumo insumo) async {
    final data = insumo.toJson()..remove('id');

    await _client
        .from('insumos')
        .update(data)
        .eq('id', insumo.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from('insumos')
        .delete()
        .eq('id', id);
  }
}