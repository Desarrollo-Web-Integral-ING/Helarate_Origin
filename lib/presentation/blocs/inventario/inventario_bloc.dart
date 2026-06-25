import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/insumo_repository.dart';
import 'inventario_event.dart';
import 'inventario_state.dart';

// Pattern: BLoC
class InventarioBloc extends Bloc<InventarioEvent, InventarioState> {
  final InsumoRepository insumoRepository;

  InventarioBloc({required this.insumoRepository}) : super(InventarioInitial()) {
    on<LoadInventario>(_onLoadInventario);
    on<AddInsumoEvent>(_onAddInsumo);
    on<UpdateInsumoEvent>(_onUpdateInsumo);
    on<DeleteInsumoEvent>(_onDeleteInsumo);
  }

  Future<void> _onLoadInventario(
      LoadInventario event, Emitter<InventarioState> emit) async {
    emit(InventarioLoading());
    try {
      final insumos = await insumoRepository.getAll();
      emit(InventarioLoaded(insumos));
    } catch (e) {
      emit(InventarioError(e.toString()));
    }
  }

  Future<void> _onAddInsumo(
      AddInsumoEvent event, Emitter<InventarioState> emit) async {
    try {
      await insumoRepository.create(event.insumo);
      add(LoadInventario());
    } catch (e) {
      emit(InventarioError(e.toString()));
    }
  }

  Future<void> _onUpdateInsumo(
      UpdateInsumoEvent event, Emitter<InventarioState> emit) async {
    try {
      await insumoRepository.update(event.insumo);
      add(LoadInventario());
    } catch (e) {
      emit(InventarioError(e.toString()));
    }
  }

  Future<void> _onDeleteInsumo(
      DeleteInsumoEvent event, Emitter<InventarioState> emit) async {
    try {
      await insumoRepository.delete(event.id);
      add(LoadInventario());
    } catch (e) {
      emit(InventarioError(e.toString()));
    }
  }
}
