import '../models/campo_personalizado.dart';

abstract class CampoPersonalizadoRepository {
  Future<List<CampoPersonalizado>> getCampos();
  Future<void> saveCampo(CampoPersonalizado campo);
  Future<void> deleteCampo(String id);
}
