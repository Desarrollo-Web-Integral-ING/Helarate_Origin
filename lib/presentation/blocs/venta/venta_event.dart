import '../../../domain/models/venta_model.dart';

// Pattern: BLoC
abstract class VentaEvent {}

class LoadVentasEvent extends VentaEvent {
  final DateTime? date;
  final DateTime? startDate;
  final DateTime? endDate;
  LoadVentasEvent({this.date, this.startDate, this.endDate});
}

class RegistrarVentaEvent extends VentaEvent {
  final VentaModel venta;
  RegistrarVentaEvent(this.venta);
}

class DeleteVentaEvent extends VentaEvent {
  final String id;
  DeleteVentaEvent(this.id);
}
