import '../models/venta_model.dart';

// Pattern: Repository
abstract class VentaRepository {
  Future<void> create(VentaModel venta);
  Future<List<VentaModel>> getByDate(DateTime date);
  Future<List<VentaModel>> getByDateRange(DateTime start, DateTime end);
  Future<void> delete(String id);
  Future<Map<String, double>> getTodaySummary();
}
