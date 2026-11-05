import '../models/asistencia.dart';
import '../models/horario_empleado.dart';

abstract class TurnosRepository {
  /// Turno sin cerrar del usuario (puede ser de un día anterior si olvidó salir).
  Future<Asistencia?> turnoAbierto(String userId);

  /// Asistencias entre dos fechas. Sin [userId] devuelve las de toda la empresa
  /// (requiere el permiso de administrar turnos).
  Future<List<Asistencia>> asistencias({
    String? userId,
    required DateTime desde,
    required DateTime hasta,
  });

  Future<Asistencia> registrarEntrada({required String userId, int retardoMinutos = 0});
  Future<Asistencia> iniciarComida(String asistenciaId);
  Future<Asistencia> terminarComida(String asistenciaId);
  Future<Asistencia> registrarSalida(String asistenciaId);

  /// Alta manual de un turno (la hace un administrador).
  Future<Asistencia> crearManual({
    required String userId,
    required DateTime fecha,
    DateTime? entrada,
    DateTime? comidaInicio,
    DateTime? comidaFin,
    DateTime? salida,
    int retardoMinutos = 0,
    String? notas,
  });

  Future<void> actualizarAsistencia(Asistencia a, {required String editadoPor});
  Future<void> eliminarAsistencia(String id);

  Future<List<HorarioEmpleado>> horarios({String? userId});
  Future<void> guardarHorarios(String userId, List<HorarioEmpleado> dias);

  Future<List<EmpleadoResumen>> empleados();
}
