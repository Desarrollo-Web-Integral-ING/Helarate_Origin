import '../../../domain/models/insumo.dart';

// Pattern: BLoC
abstract class InventarioEvent {}

class LoadInventario extends InventarioEvent {}

class AddInsumoEvent extends InventarioEvent {
  final Insumo insumo;
  AddInsumoEvent(this.insumo);
}

class UpdateInsumoEvent extends InventarioEvent {
  final Insumo insumo;
  UpdateInsumoEvent(this.insumo);
}

class DeleteInsumoEvent extends InventarioEvent {
  final String id;
  DeleteInsumoEvent(this.id);
}
