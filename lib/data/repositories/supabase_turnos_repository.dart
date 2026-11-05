import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/asistencia.dart';
import '../../domain/models/ausencia.dart';
import '../../domain/models/horario_empleado.dart';
import '../../domain/repositories/turnos_repository.dart';

class SupabaseTurnosRepository implements TurnosRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> _tenantId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('No hay una sesión activa.');
    final res = await _client.from('profiles').select('tenant_id').eq('id', userId).maybeSingle();
    final t = res?['tenant_id'] as String?;
    if (t == null) throw Exception('Tu usuario no pertenece a ninguna empresa.');
    return t;
  }

  static String _fechaSql(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _ahora() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<Asistencia?> turnoAbierto(String userId) async {
    final res = await _client
        .from('asistencias')
        .select()
        .eq('user_id', userId)
        .filter('salida', 'is', null)
        .not('entrada', 'is', null)
        .order('entrada', ascending: false)
        .limit(1);
    final list = res as List;
    if (list.isEmpty) return null;
    return Asistencia.fromJson(list.first as Map<String, dynamic>);
  }

  @override
  Future<List<Asistencia>> asistencias({
    String? userId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    var q = _client
        .from('asistencias')
        .select()
        .gte('fecha', _fechaSql(desde))
        .lte('fecha', _fechaSql(hasta));
    if (userId != null) q = q.eq('user_id', userId);
    final res = await q.order('fecha', ascending: false).order('entrada', ascending: false);
    return (res as List).map((j) => Asistencia.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Asistencia> registrarEntrada({required String userId, int retardoMinutos = 0}) async {
    final tenant = await _tenantId();
    final res = await _client
        .from('asistencias')
        .insert({
          'tenant_id': tenant,
          'user_id': userId,
          'fecha': _fechaSql(DateTime.now()),
          'entrada': _ahora(),
          'retardo_minutos': retardoMinutos,
        })
        .select()
        .single();
    return Asistencia.fromJson(res);
  }

  Future<Asistencia> _marcar(String id, Map<String, dynamic> cambios) async {
    final res = await _client.from('asistencias').update(cambios).eq('id', id).select().single();
    return Asistencia.fromJson(res);
  }

  @override
  Future<Asistencia> iniciarComida(String asistenciaId) =>
      _marcar(asistenciaId, {'comida_inicio': _ahora(), 'comida_fin': null});

  @override
  Future<Asistencia> terminarComida(String asistenciaId) =>
      _marcar(asistenciaId, {'comida_fin': _ahora()});

  @override
  Future<Asistencia> registrarSalida(String asistenciaId) =>
      _marcar(asistenciaId, {'salida': _ahora()});

  @override
  Future<Asistencia> crearManual({
    required String userId,
    required DateTime fecha,
    DateTime? entrada,
    DateTime? comidaInicio,
    DateTime? comidaFin,
    DateTime? salida,
    int retardoMinutos = 0,
    String? notas,
  }) async {
    final tenant = await _tenantId();
    final res = await _client
        .from('asistencias')
        .insert({
          'tenant_id': tenant,
          'user_id': userId,
          'fecha': _fechaSql(fecha),
          'entrada': entrada?.toUtc().toIso8601String(),
          'comida_inicio': comidaInicio?.toUtc().toIso8601String(),
          'comida_fin': comidaFin?.toUtc().toIso8601String(),
          'salida': salida?.toUtc().toIso8601String(),
          'retardo_minutos': retardoMinutos,
          'notas': notas,
          'editado_por': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return Asistencia.fromJson(res);
  }

  @override
  Future<void> actualizarAsistencia(Asistencia a, {required String editadoPor}) async {
    await _client
        .from('asistencias')
        .update({...a.toUpdateJson(), 'editado_por': editadoPor})
        .eq('id', a.id);
  }

  @override
  Future<void> eliminarAsistencia(String id) async {
    await _client.from('asistencias').delete().eq('id', id);
  }

  @override
  Future<List<HorarioEmpleado>> horarios({String? userId}) async {
    var q = _client.from('horarios_empleado').select();
    if (userId != null) q = q.eq('user_id', userId);
    final res = await q.order('dia_semana');
    return (res as List).map((j) => HorarioEmpleado.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> guardarHorarios(String userId, List<HorarioEmpleado> dias) async {
    final tenant = await _tenantId();
    await _client
        .from('horarios_empleado')
        .upsert(dias.map((d) => d.toJson(tenant)).toList(), onConflict: 'user_id,dia_semana');
  }

  @override
  Future<List<EmpleadoResumen>> empleados() async {
    final tenant = await _tenantId();
    List res;
    try {
      res = await _client
          .from('profiles')
          .select('id, nombre, rol, avatar_style, avatar_seed, avatar_png')
          .eq('tenant_id', tenant)
          .order('nombre') as List;
    } catch (_) {
      // Base sin las columnas de avatar todavía.
      res = await _client
          .from('profiles')
          .select('id, nombre, rol')
          .eq('tenant_id', tenant)
          .order('nombre') as List;
    }
    return res
        .map((j) => EmpleadoResumen(
              id: j['id'] as String,
              nombre: (j['nombre'] as String?)?.trim().isNotEmpty == true
                  ? j['nombre'] as String
                  : 'Sin nombre',
              rol: j['rol'] as String? ?? 'empleado',
              avatarStyle: j['avatar_style'] as String? ?? 'gradiente',
              avatarSeed: j['avatar_seed'] as String?,
              avatarPng: j['avatar_png'] as String?,
            ))
        .toList();
  }

  // ------------------------------------------------------------------
  // Ausencias
  // ------------------------------------------------------------------

  @override
  Future<List<Ausencia>> ausencias({
    required DateTime desde,
    required DateTime hasta,
    String? userId,
  }) async {
    var q = _client
        .from('ausencias')
        .select()
        .lte('fecha_inicio', _fechaSql(hasta))
        .gte('fecha_fin', _fechaSql(desde));
    if (userId != null) {
      q = q.or('user_id.eq.$userId,user_id.is.null');
    }
    final res = await q.order('fecha_inicio');
    return (res as List).map((j) => Ausencia.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Ausencia> crearAusencia({
    String? userId,
    required TipoAusencia tipo,
    required DateTime desde,
    required DateTime hasta,
    String? notas,
  }) async {
    final tenant = await _tenantId();
    final res = await _client
        .from('ausencias')
        .insert({
          'tenant_id': tenant,
          'user_id': userId,
          'tipo': tipo.valor,
          'fecha_inicio': _fechaSql(desde),
          'fecha_fin': _fechaSql(hasta),
          'notas': notas,
          'creado_por': _client.auth.currentUser?.id,
        })
        .select()
        .single();
    return Ausencia.fromJson(res);
  }

  @override
  Future<void> actualizarAusencia(Ausencia a) async {
    await _client.from('ausencias').update({
      'user_id': a.userId,
      'tipo': a.tipo.valor,
      'fecha_inicio': _fechaSql(a.fechaInicio),
      'fecha_fin': _fechaSql(a.fechaFin),
      'notas': a.notas,
    }).eq('id', a.id);
  }

  @override
  Future<void> eliminarAusencia(String id) async {
    await _client.from('ausencias').delete().eq('id', id);
  }

  // ------------------------------------------------------------------
  // Reglas del negocio
  // ------------------------------------------------------------------

  @override
  Future<TurnosConfig> configuracion() async {
    try {
      final tenant = await _tenantId();
      final res = await _client
          .from('turnos_config')
          .select()
          .eq('tenant_id', tenant)
          .maybeSingle();
      return res == null ? const TurnosConfig() : TurnosConfig.fromJson(res);
    } catch (_) {
      // Sin la tabla (migración pendiente) se usan los valores por defecto.
      return const TurnosConfig();
    }
  }

  @override
  Future<void> guardarConfiguracion(TurnosConfig config) async {
    final tenant = await _tenantId();
    await _client.from('turnos_config').upsert({
      'tenant_id': tenant,
      'tolerancia_retardo_min': config.toleranciaRetardoMin,
      'comida_minutos_default': config.comidaMinutosDefault,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}