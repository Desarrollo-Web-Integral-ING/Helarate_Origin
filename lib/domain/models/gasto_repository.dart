import '../models/gasto_model.dart';

abstract class GastoRepository {
  Future<void> create(GastoModel gasto);
  Future<List<GastoModel>> getByDate(DateTime date);
}