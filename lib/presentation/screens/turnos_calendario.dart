import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/di/service_locator.dart';
import '../../core/permissions/permiso.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/indexed_stack_resume.dart';
import '../../core/widgets/user_avatar.dart';
import '../../domain/models/asistencia.dart';
import '../../domain/models/ausencia.dart';
import '../../domain/models/horario_empleado.dart';
import '../../domain/repositories/turnos_repository.dart';

/// Índice de la pantalla de Turnos en la navegación principal.
const int _kTurnosTab = 8;

extension TipoAusenciaUi on TipoAusencia {
  IconData get icono {
    switch (this) {
      case TipoAusencia.vacaciones:
        return Icons.beach_access_rounded;
      case TipoAusencia.diaLibre:
        return Icons.weekend_rounded;
      case TipoAusencia.permiso:
        return Icons.assignment_ind_rounded;
      case TipoAusencia.incapacidad:
        return Icons.local_hospital_rounded;
      case TipoAusencia.festivo:
        return Icons.celebration_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TipoAusencia.vacaciones:
        return const Color(0xFF0EA5E9);
      case TipoAusencia.diaLibre:
        return const Color(0xFF8B5CF6);
      case TipoAusencia.permiso:
        return const Color(0xFFF59E0B);
      case TipoAusencia.incapacidad:
        return const Color(0xFFEF4444);
      case TipoAusencia.festivo:
        return const Color(0xFFEC4899);
    }
  }
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

String _fmtFecha(DateTime d) => DateFormat('d MMM', 'es_MX').format(d);

String _rango(Ausencia a) => a.fechaInicio == a.fechaFin
    ? _fmtFecha(a.fechaInicio)
    : '${_fmtFecha(a.fechaInicio)} – ${_fmtFecha(a.fechaFin)}';

Widget _avatarDe(EmpleadoResumen e, double size) => Tooltip(
      message: e.nombre,
      child: UserAvatar(
        style: e.avatarStyle,
        seed: e.avatarSeed ?? '',
        name: e.nombre,
        size: size,
        png: e.avatarPng,
      ),
    );

/// Calendario mensual del equipo: quién trabaja cada día (con su foto de
/// perfil), quién está de vacaciones, libre, con permiso o incapacidad, y los
/// festivos del negocio.
class CalendarioTurnosTab extends StatefulWidget {
  const CalendarioTurnosTab({super.key});

  @override
  State<CalendarioTurnosTab> createState() => _CalendarioTurnosTabState();
}

class _CalendarioTurnosTabState extends State<CalendarioTurnosTab> {
  final TurnosRepository _repo = getIt<TurnosRepository>();
  final PermissionService _perms = getIt<PermissionService>();

  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<EmpleadoResumen> _empleados = [];
  List<HorarioEmpleado> _horarios = [];
  List<Ausencia> _ausencias = [];
  String? _filtroUsuario; // null = todos
  bool _cargando = true;
  String? _error;

  bool get _admin => _perms.can(Permiso.turnosAdministrar);

  @override
  void initState() {
    super.initState();
    _cargar();
    activeTabNotifier.addListener(_onTab);
  }

  void _onTab() {
    if (activeTabNotifier.value == _kTurnosTab) _cargar(silencioso: true);
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTab);
    super.dispose();
  }

  // Primer y último día visibles en la cuadrícula (semanas completas, lunes a domingo).
  DateTime get _inicioGrid {
    final primero = DateTime(_mes.year, _mes.month, 1);
    return DateTime(primero.year, primero.month, primero.day - (primero.weekday - 1));
  }

  DateTime get _finGrid {
    final ultimo = DateTime(_mes.year, _mes.month + 1, 0);
    return DateTime(ultimo.year, ultimo.month, ultimo.day + (7 - ultimo.weekday));
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final yo = _perms.usuario;
      var emp = await _repo.empleados();
      if (!_admin && yo != null) emp = emp.where((e) => e.id == yo.id).toList();
      final hor = await _repo.horarios(userId: _admin ? null : yo?.id);
      final aus = await _repo.ausencias(
        desde: _inicioGrid,
        hasta: _finGrid,
        userId: _admin ? null : yo?.id,
      );
      if (!mounted) return;
      setState(() {
        _empleados = emp;
        _horarios = hor;
        _ausencias = aus;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString().toLowerCase();
      setState(() {
        _error = s.contains('ausencias') &&
                (s.contains('does not exist') || s.contains('pgrst205') || s.contains('schema cache'))
            ? 'Falta la tabla de ausencias. Ejecuta migracion_ausencias_calendario.sql en la base de datos.'
            : e.toString().replaceAll('Exception: ', '');
        _cargando = false;
      });
    }
  }

  void _cambiarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _cargar();
  }

  // ------------------------------------------------------------------
  // Lógica del calendario
  // ------------------------------------------------------------------

  List<EmpleadoResumen> get _visibles =>
      _filtroUsuario == null ? _empleados : _empleados.where((e) => e.id == _filtroUsuario).toList();

  Ausencia? _festivo(DateTime d) {
    for (final a in _ausencias) {
      if (a.paraTodos && a.cubre(d)) return a;
    }
    return null;
  }

  /// Ausencia propia de la persona ese día (la del negocio entero se consulta con _festivo).
  Ausencia? _ausenciaDe(String userId, DateTime d) {
    for (final a in _ausencias) {
      if (a.userId == userId && a.cubre(d)) return a;
    }
    return null;
  }

  HorarioEmpleado? _horarioDe(String userId, DateTime d) {
    for (final h in _horarios) {
      if (h.userId == userId && h.diaSemana == d.weekday && h.activo) return h;
    }
    return null;
  }

  /// Quienes trabajan ese día según su horario, sin ausencias ni festivo.
  List<EmpleadoResumen> _trabajan(DateTime d) {
    if (_festivo(d) != null) return const [];
    return _visibles.where((e) => _horarioDe(e.id, d) != null && _ausenciaDe(e.id, d) == null).toList();
  }

  List<(EmpleadoResumen, Ausencia)> _ausentes(DateTime d) {
    final out = <(EmpleadoResumen, Ausencia)>[];
    for (final e in _visibles) {
      final a = _ausenciaDe(e.id, d);
      if (a != null) out.add((e, a));
    }
    return out;
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const AppLoader(message: 'Cargando calendario...', icon: Icons.calendar_month_rounded);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: context.textMuted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(context),
                  const SizedBox(height: 10),
                  _leyenda(context),
                  const SizedBox(height: 12),
                  _cuadricula(context),
                  const SizedBox(height: 22),
                  _listaDelMes(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    final titulo = toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es_MX').format(_mes));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Mes anterior',
              onPressed: () => _cambiarMes(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Center(
                child: Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Mes siguiente',
              onPressed: () => _cambiarMes(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _mes = DateTime(DateTime.now().year, DateTime.now().month));
                _cargar();
              },
              icon: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Hoy'),
            ),
            if (_admin && _empleados.length > 1)
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String?>(
                  initialValue: _filtroUsuario,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ver a',
                    prefixIcon: Icon(Icons.filter_alt_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todo el equipo')),
                    for (final e in _empleados) DropdownMenuItem<String?>(value: e.id, child: Text(e.nombre)),
                  ],
                  onChanged: (v) => setState(() => _filtroUsuario = v),
                ),
              ),
            if (_admin)
              FilledButton.icon(
                onPressed: () => _editarAusencia(null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nueva ausencia'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _leyenda(BuildContext context) {
    Widget chip(Color c, IconData i, String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 13, color: c),
            const SizedBox(width: 5),
            Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
          ]),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(const Color(0xFF16A34A), Icons.work_rounded, 'Trabaja'),
        for (final t in TipoAusencia.values) chip(t.color, t.icono, t.etiqueta),
      ],
    );
  }

  Widget _cuadricula(BuildContext context) {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final inicio = _inicioGrid;
    final total = _finGrid.difference(inicio).inDays + 1;
    final semanas = (total / 7).ceil();

    return LayoutBuilder(
      builder: (context, c) {
        final ancho = (c.maxWidth - 6 * 4) / 7;
        final compacto = ancho < 62;
        final s = ((ancho - 10) / 3).clamp(15.0, 26.0);
        final alto = compacto ? 58.0 : 34.0 + 2 * (s + 3);

        return Column(
          children: [
            Row(
              children: [
                for (final d in dias)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: context.textMuted)),
                      ),
                    ),
                  ),
              ],
            ),
            for (var w = 0; w < semanas; w++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (var d = 0; d < 7; d++) ...[
                      Expanded(
                        child: _celda(
                          context,
                          DateTime(inicio.year, inicio.month, inicio.day + w * 7 + d),
                          ancho: ancho,
                          alto: alto,
                          compacto: compacto,
                          tamAvatar: s,
                        ),
                      ),
                      if (d < 6) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _celda(
    BuildContext context,
    DateTime dia, {
    required double ancho,
    required double alto,
    required bool compacto,
    required double tamAvatar,
  }) {
    final hoy = _dia(DateTime.now());
    final delMes = dia.month == _mes.month;
    final esHoy = dia == hoy;
    final festivo = _festivo(dia);
    final trabajan = _trabajan(dia);
    final ausentes = _ausentes(dia);

    final Color fondo = festivo != null
        ? TipoAusencia.festivo.color.withValues(alpha: 0.10)
        : (dia.weekday >= 6 ? context.textMuted.withValues(alpha: 0.05) : context.surfaceColor);

    Widget contenido;
    if (compacto) {
      contenido = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (trabajan.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.work_rounded, size: 11, color: Color(0xFF16A34A)),
                const SizedBox(width: 2),
                Text('${trabajan.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
              ],
            ),
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final t in ausentes.map((e) => e.$2.tipo).toSet())
                Container(width: 7, height: 7, decoration: BoxDecoration(color: t.color, shape: BoxShape.circle)),
              if (festivo != null)
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: TipoAusencia.festivo.color, shape: BoxShape.circle)),
            ],
          ),
        ],
      );
    } else {
      final cols = ((ancho - 8) / (tamAvatar + 2)).floor().clamp(1, 8);
      final capacidad = cols * 2;
      final todos = <Widget>[
        for (final e in trabajan) _avatarDe(e, tamAvatar),
        for (final par in ausentes)
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: par.$2.tipo.color, width: 2)),
            child: _avatarDe(par.$1, tamAvatar - 4),
          ),
      ];
      final visibles = todos.length > capacidad ? todos.take(capacidad - 1).toList() : todos;
      final extra = todos.length - visibles.length;
      contenido = Align(
        alignment: Alignment.bottomLeft,
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            ...visibles,
            if (extra > 0)
              Container(
                width: tamAvatar,
                height: tamAvatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.textMuted.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: Text('+$extra', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      );
    }

    return Opacity(
      opacity: delMes ? 1 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDia(dia),
        child: Container(
          height: alto,
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: esHoy ? context.brand : context.borderColor,
              width: esHoy ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: esHoy ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1) : EdgeInsets.zero,
                    decoration: esHoy
                        ? BoxDecoration(color: context.brand, borderRadius: BorderRadius.circular(8))
                        : null,
                    child: Text(
                      '${dia.day}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: esHoy ? Colors.white : context.textMain,
                      ),
                    ),
                  ),
                  if (festivo != null) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.celebration_rounded, size: 12, color: TipoAusencia.festivo.color),
                  ],
                ],
              ),
              Expanded(child: contenido),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaDelMes(BuildContext context) {
    final inicioMes = DateTime(_mes.year, _mes.month, 1);
    final finMes = DateTime(_mes.year, _mes.month + 1, 0);
    final del = _ausencias
        .where((a) => !a.fechaFin.isBefore(inicioMes) && !a.fechaInicio.isAfter(finMes))
        .where((a) => _filtroUsuario == null || a.userId == _filtroUsuario || a.paraTodos)
        .toList()
      ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ausencias del mes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (del.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No hay ausencias registradas este mes', style: TextStyle(color: context.textMuted)),
          ),
        for (final a in del) _filaAusencia(context, a),
      ],
    );
  }

  EmpleadoResumen? _empleado(String? id) {
    for (final e in _empleados) {
      if (e.id == id) return e;
    }
    return null;
  }

  Widget _filaAusencia(BuildContext context, Ausencia a, {bool conAcciones = true}) {
    final e = _empleado(a.userId);
    final color = a.tipo.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          if (e != null)
            _avatarDe(e, 38)
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.storefront_rounded, color: color, size: 20),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.paraTodos ? 'Todo el negocio' : (e?.nombre ?? 'Usuario'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${_rango(a)} · ${a.dias} ${a.dias == 1 ? 'día' : 'días'}${a.notas != null && a.notas!.isNotEmpty ? ' · ${a.notas}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(a.tipo.icono, size: 13, color: color),
              const SizedBox(width: 4),
              Text(a.tipo.etiqueta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
          if (_admin && conAcciones)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_rounded, size: 18),
              onPressed: () => _editarAusencia(a),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Detalle del día
  // ------------------------------------------------------------------

  void _abrirDia(DateTime dia) {
    final festivo = _festivo(dia);
    final trabajan = _trabajan(dia);
    final ausentes = _ausentes(dia);
    final descansan = _visibles
        .where((e) => _ausenciaDe(e.id, dia) == null && _horarioDe(e.id, dia) == null)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            Text(
              toBeginningOfSentenceCase(DateFormat('EEEE d \'de\' MMMM', 'es_MX').format(dia)) ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (festivo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TipoAusencia.festivo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.celebration_rounded, color: TipoAusencia.festivo.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Negocio cerrado${festivo.notas != null && festivo.notas!.isNotEmpty ? ': ${festivo.notas}' : ' (festivo)'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_admin)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editarAusencia(festivo);
                      },
                    ),
                ]),
              ),
            _seccion(context, 'Trabajan (${trabajan.length})'),
            if (trabajan.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Nadie tiene turno este día', style: TextStyle(color: context.textMuted)),
              ),
            for (final e in trabajan)
              _filaPersona(
                context,
                e,
                '${_horarioDe(e.id, dia)!.horaEntrada} – ${_horarioDe(e.id, dia)!.horaSalida}'
                ' · comida ${_horarioDe(e.id, dia)!.comidaMinutos} min',
              ),
            if (ausentes.isNotEmpty) ...[
              _seccion(context, 'Ausentes (${ausentes.length})'),
              for (final par in ausentes)
                _filaAusencia(context, par.$2, conAcciones: false)
            ],
            if (descansan.isNotEmpty) ...[
              _seccion(context, 'Descansan (${descansan.length})'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in descansan)
                    Chip(
                      avatar: _avatarDe(e, 22),
                      label: Text(e.nombre, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
            if (_admin) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _editarAusencia(null, fechaInicial: dia);
                },
                icon: const Icon(Icons.event_busy_rounded, size: 18),
                label: const Text('Agregar ausencia este día'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _seccion(BuildContext context, String titulo) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(titulo.toUpperCase(),
            style: TextStyle(
                fontSize: 11.5, letterSpacing: 0.7, fontWeight: FontWeight.w800, color: context.brand)),
      );

  Widget _filaPersona(BuildContext context, EmpleadoResumen e, String detalle) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          _avatarDe(e, 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(detalle, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ]),
          ),
        ]),
      );

  // ------------------------------------------------------------------
  // Alta / edición de ausencias
  // ------------------------------------------------------------------

  Future<void> _editarAusencia(Ausencia? existente, {DateTime? fechaInicial}) async {
    final cambio = await showDialog<bool>(
      context: context,
      builder: (_) => _AusenciaDialog(
        empleados: _empleados,
        existente: existente,
        fechaInicial: fechaInicial ?? _dia(DateTime.now()),
      ),
    );
    if (cambio == true) _cargar(silencioso: true);
  }
}

class _AusenciaDialog extends StatefulWidget {
  final List<EmpleadoResumen> empleados;
  final Ausencia? existente;
  final DateTime fechaInicial;

  const _AusenciaDialog({
    required this.empleados,
    required this.existente,
    required this.fechaInicial,
  });

  @override
  State<_AusenciaDialog> createState() => _AusenciaDialogState();
}

class _AusenciaDialogState extends State<_AusenciaDialog> {
  final TurnosRepository _repo = getIt<TurnosRepository>();
  String? _userId;
  late TipoAusencia _tipo;
  late DateTime _desde;
  late DateTime _hasta;
  final _notasCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.existente;
    _tipo = a?.tipo ?? TipoAusencia.vacaciones;
    _userId = a?.userId ?? (widget.empleados.isNotEmpty ? widget.empleados.first.id : null);
    _desde = a?.fechaInicio ?? widget.fechaInicial;
    _hasta = a?.fechaFin ?? widget.fechaInicial;
    _notasCtrl.text = a?.notas ?? '';
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirRango() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
    );
    if (r != null) {
      setState(() {
        _desde = _dia(r.start);
        _hasta = _dia(r.end);
      });
    }
  }

  Future<void> _guardar() async {
    final paraTodos = _tipo == TipoAusencia.festivo;
    if (!paraTodos && _userId == null) {
      setState(() => _error = 'Elige a la persona.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final notas = _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim();
      final uid = paraTodos ? null : _userId;
      final a = widget.existente;
      if (a == null) {
        await _repo.crearAusencia(userId: uid, tipo: _tipo, desde: _desde, hasta: _hasta, notas: notas);
      } else {
        await _repo.actualizarAusencia(Ausencia(
          id: a.id,
          tenantId: a.tenantId,
          userId: uid,
          tipo: _tipo,
          fechaInicio: _desde,
          fechaFin: _hasta,
          notas: notas,
        ));
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
        title: const Text('Eliminar ausencia'),
        content: const Text('Se quitará del calendario.'),
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
      await _repo.eliminarAusencia(widget.existente!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
        AppToast.showError(context, _error!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = _hasta.difference(_desde).inDays + 1;
    final paraTodos = _tipo == TipoAusencia.festivo;
    return AlertDialog(
      title: Text(widget.existente == null ? 'Nueva ausencia' : 'Editar ausencia'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<TipoAusencia>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in TipoAusencia.values)
                    DropdownMenuItem(
                      value: t,
                      child: Row(children: [
                        Icon(t.icono, size: 18, color: t.color),
                        const SizedBox(width: 10),
                        Text(t.etiqueta),
                      ]),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _tipo = v);
                },
              ),
              const SizedBox(height: 12),
              if (paraTodos)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TipoAusencia.festivo.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.storefront_rounded, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Aplica a todo el negocio: nadie tendrá turno esos días.')),
                  ]),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _userId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Persona', prefixIcon: Icon(Icons.person_rounded)),
                  items: [
                    for (final e in widget.empleados)
                      DropdownMenuItem(
                        value: e.id,
                        child: Row(children: [
                          UserAvatar(
                            style: e.avatarStyle,
                            seed: e.avatarSeed ?? '',
                            name: e.nombre,
                            size: 24,
                            png: e.avatarPng,
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(e.nombre, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                  ],
                  onChanged: (v) => setState(() => _userId = v),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _elegirRango,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(
                  _desde == _hasta
                      ? DateFormat('d MMM yyyy', 'es_MX').format(_desde)
                      : '${DateFormat('d MMM', 'es_MX').format(_desde)} – ${DateFormat('d MMM yyyy', 'es_MX').format(_hasta)} ($dias días)',
                ),
              ),
              const SizedBox(height: 12),
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
