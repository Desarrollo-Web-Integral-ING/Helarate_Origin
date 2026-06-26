import '../../domain/models/insumo.dart';
import '../../domain/repositories/insumo_repository.dart';

// Pattern: Repository
class SupabaseInsumoRepository implements InsumoRepository {
  // TODO: Obtener la instancia del cliente de Supabase (Supabase.instance.client)

  @override
  Future<List<Insumo>> getAll() async {
    // TODO: Consultar la tabla 'insumos' ordenada por 'nombre' de forma ascendente
    // Deserializar usando Insumo.fromJson(json)
    throw UnimplementedError();
  }

  @override
  Future<void> create(Insumo insumo) async {
    // TODO: Convertir insumo a JSON e insertarlo en la tabla 'insumos'
    throw UnimplementedError();
  }

  @override
  Future<void> update(Insumo insumo) async {
    // TODO: Convertir insumo a JSON y actualizar la fila correspondiente en 'insumos' por su id
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {
    // TODO: Eliminar la fila en la tabla 'insumos' usando su id
    throw UnimplementedError();
  }
}

