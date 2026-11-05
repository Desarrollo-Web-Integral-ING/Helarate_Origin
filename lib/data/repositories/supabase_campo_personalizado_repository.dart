import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/campo_personalizado.dart';
import '../../domain/repositories/campo_personalizado_repository.dart';

class SupabaseCampoPersonalizadoRepository implements CampoPersonalizadoRepository {
  final _client = Supabase.instance.client;
  static const String _localKeyPrefix = 'campos_personalizados_';

  String? get _currentTenantId {
    final user = _client.auth.currentUser;
    return user?.userMetadata?['tenant_id'] as String?;
  }

  @override
  Future<List<CampoPersonalizado>> getCampos() async {
    final tenantId = _currentTenantId ?? 'default';
    
    // 1. Intentar desde Supabase
    try {
      final res = await _client
          .from('campos_personalizados')
          .select()
          .order('orden', ascending: true);

      final list = (res as List).map((e) => CampoPersonalizado.fromJson(e)).toList();
      _guardarLocalmente(tenantId, list);
      return list;
    } catch (_) {
      // 2. Fallback local offline/SharedPreferences
      return await _obtenerLocalmente(tenantId);
    }
  }

  @override
  Future<void> saveCampo(CampoPersonalizado campo) async {
    final tenantId = campo.tenantId.isNotEmpty ? campo.tenantId : (_currentTenantId ?? 'default');
    final campoConTenant = campo.copyWith(tenantId: tenantId);

    // Guardar en Supabase si la tabla existe
    try {
      await _client.from('campos_personalizados').upsert(campoConTenant.toJson());
    } catch (_) {}

    // Sincronizar localmente siempre
    final actuales = await _obtenerLocalmente(tenantId);
    final idx = actuales.indexWhere((c) => c.id == campoConTenant.id);
    if (idx >= 0) {
      actuales[idx] = campoConTenant;
    } else {
      actuales.add(campoConTenant);
    }
    await _guardarLocalmente(tenantId, actuales);
  }

  @override
  Future<void> deleteCampo(String id) async {
    final tenantId = _currentTenantId ?? 'default';

    try {
      await _client.from('campos_personalizados').delete().eq('id', id);
    } catch (_) {}

    final actuales = await _obtenerLocalmente(tenantId);
    actuales.removeWhere((c) => c.id == id);
    await _guardarLocalmente(tenantId, actuales);
  }

  Future<void> _guardarLocalmente(String tenantId, List<CampoPersonalizado> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = lista.map((c) => c.toJson()).toList();
      await prefs.setString('$_localKeyPrefix$tenantId', jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<CampoPersonalizado>> _obtenerLocalmente(String tenantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_localKeyPrefix$tenantId');
      if (str == null || str.isEmpty) return [];
      final decoded = jsonDecode(str) as List;
      return decoded.map((e) => CampoPersonalizado.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

