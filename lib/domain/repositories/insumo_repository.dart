import '../models/insumo.dart';

// Pattern: Repository
abstract class InsumoRepository {
  Future<List<Insumo>> getAll();
  Future<void> create(Insumo insumo);
  Future<void> update(Insumo insumo);
  Future<void> delete(String id);
}
