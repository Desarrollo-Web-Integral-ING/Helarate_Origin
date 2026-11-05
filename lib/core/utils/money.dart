import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formateador de moneda global. Toma el símbolo/código que el negocio
/// configuró en Personalización (ej. `$`, `MXN`, `USD`).
class Money {
  Money._();

  static final Map<String, NumberFormat> _cache = {};

  /// Devuelve un [NumberFormat] para el símbolo dado.
  /// Los códigos alfabéticos (MXN, USD) llevan un espacio antes del monto.
  static NumberFormat format(String? simbolo) {
    final raw = (simbolo ?? '').trim();
    final symbol = raw.isEmpty ? '\$' : raw;
    return _cache.putIfAbsent(symbol, () {
      final isCode = RegExp(r'^[A-Za-z]+$').hasMatch(symbol);
      return NumberFormat.currency(
        locale: 'es_MX',
        symbol: isCode ? '${symbol.toUpperCase()} ' : symbol,
      );
    });
  }

  /// Formateador del negocio actual. Se actualiza solo cuando cambia la moneda.
  static NumberFormat of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MoneyScope>();
    return format(scope?.simbolo);
  }

  /// Símbolo corto para etiquetas (ej. botones rápidos de efectivo).
  static String symbolOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MoneyScope>();
    final s = (scope?.simbolo ?? '').trim();
    return s.isEmpty ? '\$' : s;
  }
}

/// Se coloca sobre el MaterialApp para que todas las pantallas se
/// reconstruyan automáticamente al cambiar la moneda.
class MoneyScope extends InheritedWidget {
  final String simbolo;

  const MoneyScope({super.key, required this.simbolo, required super.child});

  @override
  bool updateShouldNotify(MoneyScope oldWidget) => oldWidget.simbolo != simbolo;
}
