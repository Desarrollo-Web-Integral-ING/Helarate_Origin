import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/indexed_stack_resume.dart';
import '../../domain/models/asistencia.dart';
import '../../domain/models/horario_empleado.dart';
import '../../domain/repositories/turnos_repository.dart';
import '../widgets/permission_gate.dart';

/// Índice de esta pantalla en la navegación principal (main.dart).
const int kTurnosTabIndex = 8;

/// Minutos de tolerancia antes de contar un retardo.
const int kToleranciaRetardoMin = 10;

// ======================================================================
// Utilidades de formato
// ======================================================================

String _hora(DateTime? d) => d == null ? '--:--' : DateFormat('HH:mm').format(d);

String _duracion(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return '$h h ${m.toString().padLeft(2, '0')} min';
}

String _reloj(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

TimeOfDay _parseHora(String hhmm) {
  final p = hhmm.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ======================================================================
// Pantalla principal
// ======================================================================

class TurnosScreen extends StatelessWidget {
  const TurnosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final perms = getIt<PermissionService>();
    return ListenableBuilder(
      listenable: perms,
      builder: (context, _) {
        final tabs = <(String, IconData, Widget)>[
          if (perms.can(Permiso.turnosPropios))
            ('Mi turno', Icons.timer_rounded, const _MiTurnoTab()),
          if (perms.can(Permiso.turnosAdministrar)) ...[
            ('Equipo', Icons.groups_rounded, const _EquipoTab()),
            ('Horarios', Icons.calendar_month_rounded, const _HorariosTab()),
          ],
        ];
        if (tabs.isEmpty) return const AccessDeniedView(permiso: Permiso.turnosPropios);

        return DefaultTabController(
          key: ValueKey(tabs.length),
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Turnos'),
              bottom: tabs.length > 1
                  ? TabBar(
                      tabs: [for (final t in tabs) Tab(icon: Icon(t.$2), text: t.$1)],
                    )
                  : null,
            ),
            body: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final t in tabs) t.$3],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================================
// MI TURNO
// ======================================================================

class _MiTurnoTab extends StatefulWidget {
  const _MiTurnoTab();

  @override
  State<_MiTurnoTab> createState() => _MiTurnoTabState();
}

class _MiTurnoTabState extends State<_MiTurnoTab> {
  final TurnosRepository _repo = getIt<TurnosRepository>();
  final PermissionService _perms = getIt<PermissionService>();

  Asistencia? _abierto;
  List<Asistencia> _recientes = [];
  HorarioEmpleado? _horarioHoy;
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;
  DateTime _ahora = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
    activeTabNotifier.addListener(_onTab);
  }

  void _onTab() {
    if (activeTabNotifier.value == kTurnosTabIndex) _cargar(silencioso: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    activeTabNotifier.removeListener(_onTab);
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    final u = _perms.usuario;
    if (u == null) return;
    if (!silencioso) setState(() => _cargando = true);
    try {
      final hoy = _soloFecha(DateTime.now());
      final abierto = await _repo.turnoAbierto(u.id);
      final recientes = await _repo.asistencias(
        userId: u.id,
        desde: hoy.subtract(const Duration(days: 14)),
        hasta: hoy,
      );
      final horarios = await _repo.horarios(userId: u.id);
      HorarioEmpleado? hoyH;
      for (final h in horarios) {
        if (h.diaSemana == DateTime.now().weekday && h.activo) hoyH = h;
      }
      if (!mounted) return;
      setState(() {
        _abierto = abierto;
        _recientes = recientes;
        _horarioHoy = hoyH;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mensajeError(e);
        _cargando = false;
      });
    }
  }

  String _mensajeError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('asistencias') && (s.contains('does not exist') || s.contains('schema cache') || s.contains('pgrst205'))) {
      return 'Faltan las tablas de turnos en la base de datos. Ejecuta migracion_turnos_permisos.sql.';
    }
    if (s.contains('ux_asistencia_abierta') || s.contains('duplicate key')) {
      return 'Ya tienes un turno abierto. Registra primero su salida.';
    }
    if (s.contains('row-level security') || s.contains('42501')) {
      return 'No tienes permiso para registrar turnos.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> _ejecutar(Future<void> Function() accion, String ok) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) AppToast.showSuccess(context, ok);
      await _cargar(silencioso: true);
    } catch (e) {
      if (mounted) AppToast.showError(context, _mensajeError(e), title: 'No se pudo registrar');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrada() async {
    final u = _perms.usuario!;
    var retardo = 0;
    final h = _horarioHoy;
    if (h != null) {
      final minutos = DateTime.now().difference(h.entradaEn(DateTime.now())).inMinutes;
      if (minutos > kToleranciaRetardoMin) retardo = minutos;
    }
    await _ejecutar(
      () => _repo.registrarEntrada(userId: u.id, retardoMinutos: retardo),
      retardo > 0 ? 'Entrada registrada (retardo de $retardo min)' : 'Entrada registrada. ¡Buen turno!',
    );
  }

  Future<void> _salida() async {
    final t = _abierto;
    if (t == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar salida'),
        content: Text('Llevas ${_duracion(t.trabajado())} trabajados. ¿Terminar tu turno?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar salida')),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(() => _repo.registrarSalida(t.id), 'Salida registrada. ¡Buen descanso!');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const AppLoader(message: 'Cargando tu turno...', icon: Icons.timer_rounded);
    if (_error != null) {
      return _ErrorView(mensaje: _error!, onReintentar: _cargar);
    }

    final turno = _abierto;
    final hoy = _soloFecha(_ahora);
    final delDia = _recientes.where((a) => a.fecha == hoy).toList();
    final cerradoHoy = turno == null && delDia.isNotEmpty ? delDia.first : null;
    final estado = turno?.estado ?? (cerradoHoy != null ? EstadoTurno.finalizado : EstadoTurno.sinEntrada);
    final mostrado = turno ?? cerradoHoy;

    final semanaInicio = hoy.subtract(Duration(days: hoy.weekday - 1));
    final horasSemana = _recientes
        .where((a) => !a.fecha.isBefore(semanaInicio))
        .fold<Duration>(Duration.zero, (s, a) => s + a.trabajado(_ahora));

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _relojCard(context, estado),
                  const SizedBox(height: 14),
                  if (turno != null && turno.fecha != hoy)
                    _aviso(context,
                        'Tienes un turno abierto desde el ${DateFormat('d MMM', 'es_MX').format(turno.fecha)}. Registra su salida.'),
                  _contadores(context, mostrado),
                  const SizedBox(height: 14),
                  _acciones(context, estado, turno),
                  const SizedBox(height: 18),
                  _lineaDeTiempo(context, mostrado),
                  const SizedBox(height: 18),
                  _historial(context, horasSemana),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aviso(BuildContext context, String texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _relojCard(BuildContext context, EstadoTurno estado) {
    final h = _horarioHoy;
    final (etiqueta, color) = switch (estado) {
      EstadoTurno.sinEntrada => ('Sin entrada', Colors.white70),
      EstadoTurno.trabajando => ('En turno', const Color(0xFF86EFAC)),
      EstadoTurno.enComida => ('En comida', const Color(0xFFFDE68A)),
      EstadoTurno.finalizado => ('Turno terminado', const Color(0xFFBAE6FD)),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.createCustomGradient(context.brand),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: context.brand.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text(
            toBeginningOfSentenceCase(DateFormat('EEEE d MMMM', 'es_MX').format(_ahora)) ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('HH:mm:ss').format(_ahora),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(etiqueta, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            h == null
                ? 'Hoy no tienes horario asignado'
                : 'Horario de hoy: ${h.horaEntrada} – ${h.horaSalida} · comida ${h.comidaMinutos} min',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _contadores(BuildContext context, Asistencia? a) {
    final h = _horarioHoy;
    final comida = a?.comida(_ahora) ?? Duration.zero;
    final excedeComida = h != null && comida.inMinutes > h.comidaMinutos && a?.estado == EstadoTurno.enComida;

    Widget caja(String titulo, String valor, IconData icono, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icono, size: 16, color: color ?? context.textMuted),
                  const SizedBox(width: 6),
                  Text(titulo, style: TextStyle(fontSize: 12, color: context.textMuted)),
                ]),
                const SizedBox(height: 6),
                Text(valor,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        caja('Trabajado hoy', a == null ? '0 min' : _reloj(a.trabajado(_ahora)), Icons.work_history_rounded),
        const SizedBox(width: 12),
        caja('Comida', a?.comidaInicio == null ? '—' : _duracion(comida), Icons.restaurant_rounded,
            color: excedeComida ? Colors.red : null),
      ],
    );
  }

  Widget _acciones(BuildContext context, EstadoTurno estado, Asistencia? turno) {
    Widget boton(String texto, IconData icono, VoidCallback? onTap, {Color? color, bool tonal = false}) {
      final child = _ocupado
          ? const AppSpinner(size: 20, color: Colors.white)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(icono), const SizedBox(width: 10), Text(texto)],
            );
      final style = ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 18)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      );
      return tonal
          ? FilledButton.tonal(onPressed: _ocupado ? null : onTap, style: style, child: child)
          : FilledButton(
              onPressed: _ocupado ? null : onTap,
              style: style.copyWith(backgroundColor: WidgetStatePropertyAll(color ?? context.brand)),
              child: child,
            );
    }

    switch (estado) {
      case EstadoTurno.sinEntrada:
      case EstadoTurno.finalizado:
        return boton(
          estado == EstadoTurno.finalizado ? 'Registrar nueva entrada' : 'Registrar entrada',
          Icons.login_rounded,
          _entrada,
          color: const Color(0xFF16A34A),
        );
      case EstadoTurno.trabajando:
        return Column(children: [
          boton('Iniciar comida', Icons.restaurant_rounded,
              () => _ejecutar(() => _repo.iniciarComida(turno!.id), 'Comida iniciada. ¡Provecho!'),
              color: const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          boton('Registrar salida', Icons.logout_rounded, _salida, tonal: true),
        ]);
      case EstadoTurno.enComida:
        return boton('Terminar comida', Icons.restaurant_menu_rounded,
            () => _ejecutar(() => _repo.terminarComida(turno!.id), 'Comida terminada. ¡A trabajar!'),
            color: const Color(0xFF0EA5E9));
    }
  }

  Widget _lineaDeTiempo(BuildContext context, Asistencia? a) {
    Widget paso(IconData icono, String titulo, DateTime? t) {
      final hecho = t != null;
      return Expanded(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hecho ? context.brand.withValues(alpha: 0.14) : context.textMuted.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 20, color: hecho ? context.brand : context.textMuted),
            ),
            const SizedBox(height: 6),
            Text(titulo, style: TextStyle(fontSize: 11, color: context.textMuted)),
            Text(_hora(t),
                style: TextStyle(fontWeight: FontWeight.w800, color: hecho ? context.textMain : context.textMuted)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          paso(Icons.login_rounded, 'Entrada', a?.entrada),
          paso(Icons.restaurant_rounded, 'Sale a comer', a?.comidaInicio),
          paso(Icons.restaurant_menu_rounded, 'Regresa', a?.comidaFin),
          paso(Icons.logout_rounded, 'Salida', a?.salida),
        ],
      ),
    );
  }

  Widget _historial(BuildContext context, Duration horasSemana) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Últimos días', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Text('Esta semana: ${_duracion(horasSemana)}',
                style: TextStyle(fontSize: 12.5, color: context.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (_recientes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('Aún no hay registros', style: TextStyle(color: context.textMuted))),
          ),
        for (final a in _recientes)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    toBeginningOfSentenceCase(DateFormat('EEE d MMM', 'es_MX').format(a.fecha)) ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text('${_hora(a.entrada)} – ${a.salida == null ? 'en curso' : _hora(a.salida)}',
                      style: TextStyle(color: context.textMuted, fontSize: 13)),
                ),
                if (a.retardoMinutos > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Retardo ${a.retardoMinutos}m',
                        style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                Text(_duracion(a.trabajado(_ahora)), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
      ],
    );
  }
}

// ======================================================================
// EQUIPO (administradores)
// ======================================================================

class _EquipoTab extends StatefulWidget {
  const _EquipoTab();

  @override
  State<_EquipoTab> createState() => _EquipoTabState();
}

class _EquipoTabState extends State<_EquipoTab> {
  final TurnosRepository _repo = getIt<TurnosRepository>();

  static const _filtros = ['Hoy', 'Semana', 'Mes'];
  String _filtro = 'Hoy';
  List<EmpleadoResumen> _empleados = [];
  List<Asistencia> _registros = [];
  List<HorarioEmpleado> _horarios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    activeTabNotifier.addListener(_onTab);
  }

  void _onTab() {
    if (activeTabNotifier.value == kTurnosTabIndex) _cargar(silencioso: true);
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTab);
    super.dispose();
  }

  (DateTime, DateTime) get _rango {
    final hoy = _soloFecha(DateTime.now());
    switch (_filtro) {
      case 'Semana':
        return (hoy.subtract(Duration(days: hoy.weekday - 1)), hoy);
      case 'Mes':
        return (DateTime(hoy.year, hoy.month, 1), hoy);
      default:
        return (hoy, hoy);
    }
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final r = _rango;
      final emp = await _repo.empleados();
      final reg = await _repo.asistencias(desde: r.$1, hasta: r.$2);
      final hor = await _repo.horarios();
      if (!mounted) return;
      setState(() {
        _empleados = emp;
        _registros = reg;
        _horarios = hor;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _cargando = false;
      });
    }
  }

  HorarioEmpleado? _horarioDe(String userId, DateTime dia) {
    for (final h in _horarios) {
      if (h.userId == userId && h.diaSemana == dia.weekday && h.activo) return h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const AppLoader(message: 'Cargando equipo...', icon: Icons.groups_rounded);
    if (_error != null) return _ErrorView(mensaje: _error!, onReintentar: _cargar);

    final ahora = DateTime.now();
    final hoy = _soloFecha(ahora);
    final porUsuario = <String, List<Asistencia>>{};
    for (final a in _registros) {
      porUsuario.putIfAbsent(a.userId, () => []).add(a);
    }

    var enTurno = 0, enComida = 0, sinEntrada = 0;
    for (final e in _empleados) {
      final regs = porUsuario[e.id] ?? [];
      final abierto = regs.where((a) => a.abierto).toList();
      if (abierto.isNotEmpty) {
        abierto.first.estado == EstadoTurno.enComida ? enComida++ : enTurno++;
      } else if (regs.where((a) => a.fecha == hoy).isEmpty && _horarioDe(e.id, hoy) != null) {
        sinEntrada++;
      }
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in _filtros)
                        ChoiceChip(
                          label: Text(f),
                          selected: _filtro == f,
                          onSelected: (_) {
                            setState(() => _filtro = f);
                            _cargar();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _resumen(context, 'En turno', enTurno, Colors.green),
                      const SizedBox(width: 10),
                      _resumen(context, 'En comida', enComida, Colors.orange),
                      const SizedBox(width: 10),
                      _resumen(context, 'Sin entrada', sinEntrada, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_empleados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(child: Text('No hay usuarios en tu empresa', style: TextStyle(color: context.textMuted))),
                    ),
                  for (final e in _empleados) _empleadoTile(context, e, porUsuario[e.id] ?? [], hoy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen(BuildContext context, String titulo, int n, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text('$n', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            Text(titulo, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _empleadoTile(BuildContext context, EmpleadoResumen e, List<Asistencia> regs, DateTime hoy) {
    final total = regs.fold<Duration>(Duration.zero, (s, a) => s + a.trabajado());
    final retardos = regs.where((a) => a.retardoMinutos > 0).length;
    final abierto = regs.where((a) => a.abierto).toList();
    final prog = _horarioDe(e.id, hoy);

    late final String estadoTxt;
    late final Color estadoColor;
    if (abierto.isNotEmpty) {
      final a = abierto.first;
      estadoTxt = a.estado == EstadoTurno.enComida
          ? 'En comida desde ${_hora(a.comidaInicio)}'
          : 'En turno desde ${_hora(a.entrada)}';
      estadoColor = a.estado == EstadoTurno.enComida ? Colors.orange : Colors.green;
    } else if (regs.any((a) => a.fecha == hoy)) {
      final a = regs.firstWhere((a) => a.fecha == hoy);
      estadoTxt = 'Salió a las ${_hora(a.salida)}';
      estadoColor = Colors.blueGrey;
    } else if (prog != null) {
      estadoTxt = 'Sin entrada · esperado ${prog.horaEntrada}';
      estadoColor = Colors.red;
    } else {
      estadoTxt = 'Sin horario hoy';
      estadoColor = Colors.grey;
    }

    final subtitulo = _filtro == 'Hoy'
        ? estadoTxt
        : '${regs.length} turnos · ${_duracion(total)}${retardos > 0 ? ' · $retardos retardos' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: context.brand.withValues(alpha: 0.14),
            child: Text(
              e.nombre.isNotEmpty ? e.nombre[0].toUpperCase() : '?',
              style: TextStyle(color: context.brand, fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Row(
            children: [
              if (_filtro == 'Hoy') ...[
                Icon(Icons.circle, size: 9, color: estadoColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  '${Permiso.etiquetaRol(e.rol)} · $subtitulo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (regs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin registros en este periodo', style: TextStyle(color: context.textMuted)),
              ),
            for (final a in regs)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _editar(e, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(DateFormat('EEE d MMM', 'es_MX').format(a.fecha),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(
                          '${_hora(a.entrada)} → ${a.salida == null ? 'en curso' : _hora(a.salida)}'
                          '${a.comidaInicio != null ? '  · 🍽 ${_hora(a.comidaInicio)}-${_hora(a.comidaFin)}' : ''}',
                          style: TextStyle(fontSize: 12.5, color: context.textMuted),
                        ),
                      ),
                      if (a.retardoMinutos > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text('+${a.retardoMinutos}m',
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      Text(_duracion(a.trabajado()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_rounded, size: 16, color: context.textMuted),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _editar(e, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar registro manual'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editar(EmpleadoResumen emp, Asistencia? existente) async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => _EditarAsistenciaDialog(empleado: emp, existente: existente),
    );
    if (cambio == true) _cargar(silencioso: true);
  }
}

class _EditarAsistenciaDialog extends StatefulWidget {
  final EmpleadoResumen empleado;
  final Asistencia? existente;
  const _EditarAsistenciaDialog({required this.empleado, required this.existente});

  @override
  State<_EditarAsistenciaDialog> createState() => _EditarAsistenciaDialogState();
}

class _EditarAsistenciaDialogState extends State<_EditarAsistenciaDialog> {
  final TurnosRepository _repo = getIt<TurnosRepository>();
  final PermissionService _perms = getIt<PermissionService>();
  late DateTime _fecha;
  DateTime? _entrada, _comidaIni, _comidaFin, _salida;
  final _notasCtrl = TextEditingController();
  final _retardoCtrl = TextEditingController(text: '0');
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.existente;
    _fecha = a?.fecha ?? _soloFecha(DateTime.now());
    _entrada = a?.entrada;
    _comidaIni = a?.comidaInicio;
    _comidaFin = a?.comidaFin;
    _salida = a?.salida;
    _notasCtrl.text = a?.notas ?? '';
    _retardoCtrl.text = (a?.retardoMinutos ?? 0).toString();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _retardoCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _elegir(DateTime? actual, {DateTime? despuesDe}) async {
    final base = actual ?? DateTime.now();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return actual;
    var d = DateTime(_fecha.year, _fecha.month, _fecha.day, t.hour, t.minute);
    // Turnos que cruzan la medianoche: si queda antes de la referencia, es del día siguiente.
    if (despuesDe != null && d.isBefore(despuesDe)) d = d.add(const Duration(days: 1));
    return d;
  }

  Future<void> _elegirFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _fecha = _soloFecha(d));
  }

  Widget _fila(String titulo, DateTime? valor, ValueChanged<DateTime?> onCambio, {DateTime? despuesDe}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(titulo),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async => onCambio(await _elegir(valor, despuesDe: despuesDe)),
            child: Text(valor == null ? 'Poner hora' : _hora(valor),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (valor != null)
            IconButton(
              tooltip: 'Quitar',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => onCambio(null),
            ),
        ],
      ),
    );
  }

  Future<void> _guardar() async {
    if (_entrada == null && (_salida != null || _comidaIni != null)) {
      setState(() => _error = 'Pon primero la hora de entrada.');
      return;
    }
    if (_comidaFin != null && _comidaIni == null) {
      setState(() => _error = 'Falta la hora en que salió a comer.');
      return;
    }
    if (_entrada != null && _salida != null && !_salida!.isAfter(_entrada!)) {
      setState(() => _error = 'La salida debe ser posterior a la entrada.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final retardo = int.tryParse(_retardoCtrl.text.trim()) ?? 0;
      final notas = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
      final a = widget.existente;
      if (a == null) {
        await _repo.crearManual(
          userId: widget.empleado.id,
          fecha: _fecha,
          entrada: _entrada,
          comidaInicio: _comidaIni,
          comidaFin: _comidaFin,
          salida: _salida,
          retardoMinutos: retardo,
          notas: notas,
        );
      } else {
        await _repo.actualizarAsistencia(
          Asistencia(
            id: a.id,
            userId: a.userId,
            tenantId: a.tenantId,
            fecha: _fecha,
            entrada: _entrada,
            comidaInicio: _comidaIni,
            comidaFin: _comidaFin,
            salida: _salida,
            retardoMinutos: retardo,
            notas: notas,
          ),
          editadoPor: _perms.usuario?.id ?? '',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('Se borrará este turno. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _guardando = true);
    try {
      await _repo.eliminarAsistencia(widget.existente!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Registro manual' : 'Editar registro'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.empleado.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Día'),
                trailing: TextButton(
                  onPressed: widget.existente == null ? _elegirFecha : null,
                  child: Text(DateFormat('d MMM yyyy', 'es_MX').format(_fecha),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              _fila('Entrada', _entrada, (v) => setState(() => _entrada = v)),
              _fila('Sale a comer', _comidaIni, (v) => setState(() => _comidaIni = v), despuesDe: _entrada),
              _fila('Regresa de comer', _comidaFin, (v) => setState(() => _comidaFin = v), despuesDe: _comidaIni),
              _fila('Salida', _salida, (v) => setState(() => _salida = v), despuesDe: _entrada),
              const SizedBox(height: 8),
              TextField(
                controller: _retardoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Minutos de retardo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existente != null)
          TextButton(
            onPressed: _guardando ? null : _eliminar,
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando ? const AppSpinner(size: 18, color: Colors.white) : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ======================================================================
// HORARIOS (administradores)
// ======================================================================

class _HorariosTab extends StatefulWidget {
  const _HorariosTab();

  @override
  State<_HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends State<_HorariosTab> {
  final TurnosRepository _repo = getIt<TurnosRepository>();

  List<EmpleadoResumen> _empleados = [];
  String? _seleccionado;
  Map<int, HorarioEmpleado> _borrador = {};
  bool _cargando = true;
  bool _cargandoHorario = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    setState(() => _cargando = true);
    try {
      final emp = await _repo.empleados();
      if (!mounted) return;
      setState(() {
        _empleados = emp;
        _error = null;
        _cargando = false;
      });
      if (emp.isNotEmpty) _seleccionar(emp.first.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _cargando = false;
      });
    }
  }

  Future<void> _seleccionar(String userId) async {
    setState(() {
      _seleccionado = userId;
      _cargandoHorario = true;
    });
    try {
      final guardados = await _repo.horarios(userId: userId);
      final mapa = <int, HorarioEmpleado>{};
      for (var d = 1; d <= 7; d++) {
        final g = guardados.where((h) => h.diaSemana == d).toList();
        mapa[d] = g.isNotEmpty
            ? g.first
            : HorarioEmpleado(userId: userId, diaSemana: d, activo: d <= 5);
      }
      if (!mounted) return;
      setState(() {
        _borrador = mapa;
        _cargandoHorario = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoHorario = false);
      AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _elegirHora(int dia, bool esEntrada) async {
    final h = _borrador[dia]!;
    final t = await showTimePicker(
      context: context,
      initialTime: _parseHora(esEntrada ? h.horaEntrada : h.horaSalida),
    );
    if (t == null) return;
    setState(() {
      _borrador[dia] = esEntrada ? h.copyWith(horaEntrada: _hhmm(t)) : h.copyWith(horaSalida: _hhmm(t));
    });
  }

  void _aplicarALunesAViernes() {
    final base = _borrador.values.firstWhere((h) => h.activo, orElse: () => _borrador[1]!);
    setState(() {
      for (var d = 1; d <= 5; d++) {
        _borrador[d] = _borrador[d]!.copyWith(
          horaEntrada: base.horaEntrada,
          horaSalida: base.horaSalida,
          comidaMinutos: base.comidaMinutos,
          activo: true,
        );
      }
    });
    AppToast.showInfo(context, 'Se copió ${base.horaEntrada} – ${base.horaSalida} a lunes–viernes');
  }

  Future<void> _guardar() async {
    final id = _seleccionado;
    if (id == null) return;
    for (final h in _borrador.values) {
      if (h.activo && h.horaSalida.compareTo(h.horaEntrada) <= 0) {
        AppToast.showWarning(context, 'La salida del ${h.nombreDia} debe ser después de la entrada.');
        return;
      }
    }
    setState(() => _guardando = true);
    try {
      await _repo.guardarHorarios(id, _borrador.values.toList());
      if (mounted) AppToast.showSuccess(context, 'Horario guardado');
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString().replaceAll('Exception: ', ''), title: 'No se pudo guardar');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const AppLoader(message: 'Cargando...', icon: Icons.calendar_month_rounded);
    if (_error != null) return _ErrorView(mensaje: _error!, onReintentar: _cargarEmpleados);
    if (_empleados.isEmpty) {
      return Center(child: Text('No hay usuarios en tu empresa', style: TextStyle(color: context.textMuted)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _seleccionado,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Empleado', prefixIcon: Icon(Icons.person_rounded)),
                  items: [
                    for (final e in _empleados)
                      DropdownMenuItem(value: e.id, child: Text('${e.nombre} · ${Permiso.etiquetaRol(e.rol)}')),
                  ],
                  onChanged: (v) {
                    if (v != null) _seleccionar(v);
                  },
                ),
                const SizedBox(height: 14),
                if (_cargandoHorario)
                  const Padding(padding: EdgeInsets.all(30), child: AppLoader(size: 48))
                else ...[
                  for (var d = 1; d <= 7; d++) _filaDia(context, _borrador[d]!),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _aplicarALunesAViernes,
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        label: const Text('Copiar a lunes–viernes'),
                      ),
                      FilledButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const AppSpinner(size: 18, color: Colors.white)
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Guardar horario'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filaDia(BuildContext context, HorarioEmpleado h) {
    final activo = h.activo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activo ? context.brand.withValues(alpha: 0.4) : context.borderColor),
      ),
      child: Row(
        children: [
          Switch(
            value: activo,
            onChanged: (v) => setState(() => _borrador[h.diaSemana] = h.copyWith(activo: v)),
          ),
          SizedBox(
            width: 82,
            child: Text(h.nombreDia,
                style: TextStyle(fontWeight: FontWeight.w700, color: activo ? null : context.textMuted)),
          ),
          Expanded(
            child: activo
                ? Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _elegirHora(h.diaSemana, true),
                        child: Text(h.horaEntrada, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Text('→'),
                      TextButton(
                        onPressed: () => _elegirHora(h.diaSemana, false),
                        child: Text(h.horaSalida, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Icon(Icons.restaurant_rounded, size: 16),
                      DropdownButton<int>(
                        value: const [0, 15, 30, 45, 60, 90].contains(h.comidaMinutos) ? h.comidaMinutos : 30,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final m in const [0, 15, 30, 45, 60, 90])
                            DropdownMenuItem(value: m, child: Text(m == 0 ? 'Sin comida' : '$m min')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _borrador[h.diaSemana] = h.copyWith(comidaMinutos: v));
                        },
                      ),
                    ],
                  )
                : Text('Descanso', style: TextStyle(color: context.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() onReintentar;
  const _ErrorView({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: context.textMuted),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
