import 'package:flutter_test/flutter_test.dart';
import 'package:nevero_app/domain/models/insumo.dart';

void main() {
  test('Insumo stockBajo test', () {
    final insumo = Insumo(
      id: '1',
      nombre: 'Vaso',
      unidad: 'Piezas',
      costoUnitario: 1.0,
      stockActual: 5.0,
      stockMinimo: 10.0,
      tipo: TipoInsumo.materiaPrima,
      precioVenta: 0.0,
      categoria: 'General',
      updatedAt: DateTime.now(),
    );

    expect(insumo.stockBajo, isTrue);
  });
}
