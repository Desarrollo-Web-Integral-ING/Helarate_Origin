import '../../../domain/models/venta_model.dart';

// Pattern: BLoC
abstract class VentaState {}

class VentaInitial extends VentaState {}

class VentaLoading extends VentaState {}

class VentasLoaded extends VentaState {
  final List<VentaModel> ventas;
  VentasLoaded(this.ventas);
}

class VentaSuccess extends VentaState {}

class VentaError extends VentaState {
  final String message;
  VentaError(this.message);
}
