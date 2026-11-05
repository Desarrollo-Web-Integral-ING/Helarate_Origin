import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/di/service_locator.dart';
import '../../core/hardware/hardware_service.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/business_icon_helper.dart';
import '../../domain/models/tenant_model.dart';
import '../../domain/models/venta_model.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../screens/hardware_screen.dart';

/// Ticket de venta con los datos del negocio (nombre, logo, dirección,
/// teléfono y mensaje de agradecimiento configurados en Personalización).
class ReceiptDialog extends StatelessWidget {
  final VentaModel venta;
  final double? efectivoRecibido;

  const ReceiptDialog({super.key, required this.venta, this.efectivoRecibido});

  static Future<void> show(
    BuildContext context,
    VentaModel venta, {
    double? efectivoRecibido,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar ticket',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) =>
          ReceiptDialog(venta: venta, efectivoRecibido: efectivoRecibido),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  String get _folio => venta.id.length >= 8
      ? venta.id.substring(0, 8).toUpperCase()
      : venta.id.toUpperCase();

  String _plainText(TenantModel? t, NumberFormat fmt) {
    final b = StringBuffer();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha);
    b.writeln(t?.nombre ?? 'Punto de Venta');
    if ((t?.direccion ?? '').isNotEmpty) b.writeln(t!.direccion);
    if ((t?.telefono ?? '').isNotEmpty) b.writeln('Tel: ${t!.telefono}');
    b.writeln('--------------------------------');
    b.writeln('Folio: $_folio');
    b.writeln('Fecha: $date');
    b.writeln('--------------------------------');
    for (final d in venta.detalles) {
      b.writeln(d.insumoNombre ?? 'Producto');
      b.writeln(
          '  ${d.cantidad.toInt()} x ${fmt.format(d.precioVentaUnitario)} = ${fmt.format(d.total)}');
    }
    b.writeln('--------------------------------');
    b.writeln('TOTAL: ${fmt.format(venta.totalIngresos)}');
    if (efectivoRecibido != null && efectivoRecibido! > 0) {
      b.writeln('Recibido: ${fmt.format(efectivoRecibido)}');
      b.writeln(
          'Cambio: ${fmt.format((efectivoRecibido! - venta.totalIngresos).clamp(0, double.infinity))}');
    }
    b.writeln('--------------------------------');
    b.writeln(t?.mensajeRecibo ?? '¡Gracias por su compra!');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final tenant = authState is Authenticated ? authState.tenant : null;
    final fmt = Money.of(context);
    final brand = Theme.of(context).colorScheme.primary;
    final mq = MediaQuery.of(context);

    const ink = Color(0xFF1E293B);
    const muted = Color(0xFF64748B);
    final mono = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      color: ink,
      height: 1.4,
    );

    final cambio = (efectivoRecibido != null && efectivoRecibido! > 0)
        ? efectivoRecibido! - venta.totalIngresos
        : null;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: mq.size.height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ClipPath(
                    clipper: _ZigZagClipper(),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _logo(tenant, brand)),
                            const SizedBox(height: 10),
                            Text(
                              tenant?.nombre ?? 'Punto de Venta',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            if ((tenant?.direccion ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(tenant!.direccion!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12, color: muted)),
                              ),
                            if ((tenant?.telefono ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('Tel: ${tenant!.telefono}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 12, color: muted)),
                              ),
                            const SizedBox(height: 12),
                            const _Dashed(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Folio: $_folio', style: mono),
                                Text(
                                  DateFormat('dd/MM/yy HH:mm')
                                      .format(venta.fecha),
                                  style: mono,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const _Dashed(),
                            const SizedBox(height: 8),
                            if (venta.detalles.isEmpty)
                              Text('Sin detalle de productos', style: mono),
                            for (final d in venta.detalles)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.insumoNombre ?? 'Producto',
                                        style: mono.copyWith(
                                            fontWeight: FontWeight.w700)),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            '${d.cantidad.toInt()} x ${fmt.format(d.precioVentaUnitario)}',
                                            style: mono),
                                        Text(fmt.format(d.total), style: mono),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const _Dashed(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: ink)),
                                Text(fmt.format(venta.totalIngresos),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: ink)),
                              ],
                            ),
                            if (cambio != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Recibido', style: mono),
                                  Text(fmt.format(efectivoRecibido),
                                      style: mono),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Cambio', style: mono),
                                  Text(
                                      fmt.format(cambio < 0 ? 0 : cambio),
                                      style: mono.copyWith(
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            const _Dashed(),
                            const SizedBox(height: 12),
                            Text(
                              tenant?.mensajeRecibo ??
                                  '¡Gracias por su compra!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildActions(context, tenant, fmt),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Listo'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  /// Botones de acción. "Imprimir" solo aparece si esta terminal tiene una
  /// impresora configurada y conectada; si no, el ticket queda en pantalla.
  Widget _buildActions(BuildContext context, TenantModel? tenant, NumberFormat fmt) {
    final hw = getIt<HardwareService>();
    return ListenableBuilder(
      listenable: hw,
      builder: (context, _) {
        final configured = hw.settings.printerConfigured;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    icon: Icons.copy_rounded,
                    label: 'Copiar',
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: _plainText(tenant, fmt)));
                      if (context.mounted) {
                        AppToast.showSuccess(
                            context, 'Ticket copiado al portapapeles');
                      }
                    },
                  ),
                ),
                if (configured) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: hw.canPrintManually
                        ? _GhostButton(
                            icon: Icons.print_rounded,
                            label: 'Imprimir',
                            onPressed: () async {
                              final r = await hw.printReceipt(
                                venta: venta,
                                fmt: fmt,
                                tenant: tenant,
                                efectivoRecibido: efectivoRecibido,
                                manual: true,
                              );
                              if (!context.mounted) return;
                              if (r.ok) {
                                AppToast.showSuccess(context, r.message);
                              } else {
                                AppToast.showError(context, r.message,
                                    title: 'No se pudo imprimir');
                              }
                            },
                          )
                        : _GhostButton(
                            icon: Icons.sync_problem_rounded,
                            label: 'Reintentar impresora',
                            onPressed: () async {
                              await hw.refreshStatus();
                              if (!context.mounted) return;
                              if (hw.canPrintManually) {
                                AppToast.showSuccess(context, hw.statusDetail,
                                    title: 'Impresora conectada');
                              } else {
                                AppToast.showWarning(context, hw.statusDetail,
                                    title: 'Impresora sin conexión');
                              }
                            },
                          ),
                  ),
                ],
              ],
            ),
            if (!configured)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HardwareScreen()),
                  ),
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Sin impresora configurada · Configurar'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _logo(TenantModel? tenant, Color brand) {
    final logo = tenant?.logoUrl;
    if (logo != null && logo.isNotEmpty) {
      try {
        final bytes = base64Decode(logo.contains(',') ? logo.split(',').last : logo);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _iconLogo(tenant, brand)),
        );
      } catch (_) {}
    }
    return _iconLogo(tenant, brand);
  }

  Widget _iconLogo(TenantModel? tenant, Color brand) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(BusinessIconHelper.getIcon(tenant?.logoIcon),
          color: brand, size: 28),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _GhostButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final count = (c.maxWidth / 7).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          count,
          (_) => Container(width: 4, height: 1.2, color: const Color(0xFFCBD5E1)),
        ),
      );
    });
  }
}

class _ZigZagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const tooth = 8.0;
    final path = Path()..moveTo(0, 0);
    path.lineTo(0, size.height - tooth);
    var x = 0.0;
    var down = true;
    while (x < size.width) {
      x = (x + tooth).clamp(0.0, size.width).toDouble();
      path.lineTo(x, size.height - (down ? 0 : tooth));
      down = !down;
    }
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
