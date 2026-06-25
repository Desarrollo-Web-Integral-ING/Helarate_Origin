import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/insumo.dart';
import '../../domain/repositories/insumo_repository.dart';

// Pattern: Repository
class SupabaseInsumoRepository implements InsumoRepository {
  final _client = Supabase.instance.client;

  @override
  Future<List<Insumo>> getAll() async {
    final response = await _client
        .from('insumos')
        .select()
        .order('nombre', ascending: true);
    
    return (response as List).map((json) => Insumo.fromJson(json)).toList();
  }

  @override
  Future<void> create(Insumo insumo) async {
    final data = insumo.toJson();
    // Remover updated_at para que Postgres use el valor por defecto de trigger/columna si es necesario, 
    // o enviarlo directamente.
    await _client.from('insumos').insert(data);
  }

  @override
  Future<void> update(Insumo insumo) async {
    final data = insumo.toJson();
    // Remover id para evitar actualizar la llave primaria
    data.remove('id');
    data['updated_at'] = DateTime.now().toIso8601String();
    
    await _client.from('insumos').update(data).eq('id', insumo.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('insumos').delete().eq('id', id);
  }
}
