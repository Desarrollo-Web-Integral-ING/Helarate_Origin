import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/usuario_perfil.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final _client = Supabase.instance.client;

  Future<UsuarioPerfil?> _getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // Si por alguna razón el trigger de base de datos no creó el perfil,
        // lo creamos dinámicamente.
        final currentUser = _client.auth.currentUser;
        final defaultProfile = {
          'id': userId,
          'nombre': currentUser?.userMetadata?['nombre'] ?? 'Usuario Nuevo',
          'rol': 'empleado',
        };
        await _client.from('profiles').insert(defaultProfile);
        
        return UsuarioPerfil(
          id: userId,
          nombre: defaultProfile['nombre'] as String,
          rol: defaultProfile['rol'] as String,
          createdAt: DateTime.now(),
        );
      }

      return UsuarioPerfil.fromJson(response);
    } catch (e) {
      print('Error al obtener perfil: $e');
      // Retornar un perfil básico por seguridad para evitar crash
      return UsuarioPerfil(
        id: userId,
        nombre: 'Usuario',
        rol: 'empleado',
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<UsuarioPerfil?> getCurrentUser() async {
    final sessionUser = _client.auth.currentUser;
    if (sessionUser == null) return null;
    return await _getUserProfile(sessionUser.id);
  }

  @override
  Stream<UsuarioPerfil?> get onAuthStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((data) async {
      final sessionUser = data.session?.user;
      if (sessionUser == null) return null;
      return await _getUserProfile(sessionUser.id);
    });
  }

  @override
  Future<UsuarioPerfil?> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) return null;

    try {
      await _client
          .from('profiles')
          .update({'aceptado_aviso_at': DateTime.now().toIso8601String()})
          .eq('id', response.user!.id);
    } catch (e) {
      print('Error al actualizar fecha de aceptación de aviso en inicio de sesión: $e');
    }

    return await _getUserProfile(response.user!.id);
  }

  @override
  Future<UsuarioPerfil?> signUpWithEmail(
    String email,
    String password,
    String nombre,
    String rol,
  ) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nombre': nombre,
        'rol': rol,
      },
    );
    if (response.user == null) return null;

    try {
      await _client
          .from('profiles')
          .update({'aceptado_aviso_at': DateTime.now().toIso8601String()})
          .eq('id', response.user!.id);
    } catch (e) {
      print('Error al registrar fecha de aceptación de aviso en registro: $e');
    }

    return await _getUserProfile(response.user!.id);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('profiles').delete().eq('id', user.id);
    } catch (e) {
      print('Error al borrar perfil: $e');
    }
    await signOut();
  }
}
