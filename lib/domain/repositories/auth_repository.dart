import '../models/usuario_perfil.dart';

abstract class AuthRepository {
  Future<UsuarioPerfil?> signInWithEmail(String email, String password);
  Future<UsuarioPerfil?> signUpWithEmail(
      String email, String password, String nombre, String rol);
  Future<void> signOut();
  Future<UsuarioPerfil?> getCurrentUser();
  Stream<UsuarioPerfil?> get onAuthStateChanges;
  Future<void> deleteAccount();

  /// Derecho de Rectificación (ARCO): actualiza el nombre del perfil
  /// autenticado en Supabase y devuelve el perfil ya actualizado.
  Future<UsuarioPerfil> updateProfile(String nombre);
}
