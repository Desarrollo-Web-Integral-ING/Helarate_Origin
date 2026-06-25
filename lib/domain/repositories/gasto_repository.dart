import '../models/gasto_model.dart';

// Pattern: Repository
abstract class GastoRepository {
  Future<void> create(GastoModel gasto);
  Future<List<GastoModel>> getByDate(DateTime date);
}
