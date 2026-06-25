import '../models/venta_model.dart';

// Pattern: Repository
abstract class VentaRepository {
  Future<void> create(VentaModel venta);
  Future<List<VentaModel>> getByDate(DateTime date);
  Future<Map<String, double>> getTodaySummary();
}
