import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/venta_repository.dart';
import 'venta_event.dart';
import 'venta_state.dart';

// Pattern: BLoC
class VentaBloc extends Bloc<VentaEvent, VentaState> {
  final VentaRepository ventaRepository;

  VentaBloc({required this.ventaRepository}) : super(VentaInitial()) {
    on<LoadVentasEvent>(_onLoadVentas);
    on<RegistrarVentaEvent>(_onRegistrarVenta);
    on<DeleteVentaEvent>(_onDeleteVenta);
  }

  Future<void> _onLoadVentas(
      LoadVentasEvent event, Emitter<VentaState> emit) async {
    emit(VentaLoading());
    try {
      final List<VentaModel> ventas;
      if (event.startDate != null && event.endDate != null) {
        ventas = await ventaRepository.getByDateRange(event.startDate!, event.endDate!);
      } else {
        ventas = await ventaRepository.getByDate(event.date ?? DateTime.now());
      }
      emit(VentasLoaded(ventas));
    } catch (e) {
      emit(VentaError(e.toString()));
    }
  }

  Future<void> _onRegistrarVenta(
      RegistrarVentaEvent event, Emitter<VentaState> emit) async {
    emit(VentaLoading());
    try {
      await ventaRepository.create(event.venta);
      emit(VentaSuccess());
      add(LoadVentasEvent());
    } catch (e) {
      emit(VentaError(e.toString()));
    }
  }

  Future<void> _onDeleteVenta(
      DeleteVentaEvent event, Emitter<VentaState> emit) async {
    emit(VentaLoading());
    try {
      await ventaRepository.delete(event.id);
      emit(VentaSuccess());
      add(LoadVentasEvent());
    } catch (e) {
      emit(VentaError(e.toString()));
    }
  }
}
