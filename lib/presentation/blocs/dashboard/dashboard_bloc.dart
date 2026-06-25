import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/insumo_repository.dart';
import '../../../domain/repositories/venta_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

// Pattern: BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final InsumoRepository insumoRepository;
  final VentaRepository ventaRepository;

  DashboardBloc({
    required this.insumoRepository,
    required this.ventaRepository,
  }) : super(DashboardInitial()) {
    on<LoadDashboardEvent>(_onLoadDashboard);
  }

  Future<void> _onLoadDashboard(
      LoadDashboardEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final insumos = await insumoRepository.getAll();
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      final ventas = await ventaRepository.getByDateRange(startOfMonth, endOfMonth);
      
      emit(DashboardLoaded(
        insumos: insumos,
        ventas: ventas,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
