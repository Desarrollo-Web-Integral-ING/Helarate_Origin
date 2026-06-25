import '../../../domain/models/insumo.dart';
import '../../../domain/models/venta_model.dart';

// Pattern: BLoC
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Insumo> insumos;
  final List<VentaModel> ventas;

  DashboardLoaded({
    required this.insumos,
    required this.ventas,
  });
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}
