import '../../../domain/models/insumo.dart';

// Pattern: BLoC
abstract class InventarioState {}

class InventarioInitial extends InventarioState {}

class InventarioLoading extends InventarioState {}

class InventarioLoaded extends InventarioState {
  final List<Insumo> insumos;
  InventarioLoaded(this.insumos);
}

class InventarioError extends InventarioState {
  final String message;
  InventarioError(this.message);
}
