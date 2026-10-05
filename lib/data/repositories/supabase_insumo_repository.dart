import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/insumo.dart';
import '../../domain/repositories/insumo_repository.dart';


class SupabaseInsumoRepository implements InsumoRepository {
  final _client = Supabase.instance.client;

  Future<String?> _getTenantId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await _client.from('profiles').select('tenant_id').eq('id', userId).maybeSingle();
    return res?['tenant_id'] as String?;
  }


  @override
  Future<List<Insumo>> getAll() async {
    final tenantId = await _getTenantId();
    var query = _client.from('insumos').select();
    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }
    
    final response = await query.order('nombre', ascending: true);
    return (response as List)
        .map((json) => Insumo.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> create(Insumo insumo) async {
    final tenantId = await _getTenantId();
    final data = insumo.toJson();
    data['tenant_id'] = tenantId;
    await _client.from('insumos').insert(data);
  }

  @override
  Future<void> update(Insumo insumo) async {
    final tenantId = await _getTenantId();
    final data = insumo.toJson()..remove('id');
    data['tenant_id'] = tenantId;
    await _client.from('insumos').update(data).eq('id', insumo.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from('insumos')
        .delete()
        .eq('id', id);
  }

  @override
  Future<String?> uploadImage(String name, List<int> bytes, String extension) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$name.$extension';
      final fileData = Uint8List.fromList(bytes);
      
      await _client.storage.from('insumos_images').uploadBinary(
        fileName,
        fileData,
        fileOptions: FileOptions(
          contentType: 'image/$extension',
          cacheControl: '3600',
        ),
      );

      final String publicUrl = _client.storage
          .from('insumos_images')
          .getPublicUrl(fileName);
          
      return publicUrl;
    } catch (e) {
      print('Error al subir imagen a Supabase Storage: $e');
      return null;
    }
  }
}