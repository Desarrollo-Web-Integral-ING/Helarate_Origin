import '../models/usuario_perfil.dart';

abstract class AuthRepository {
  Future<UsuarioPerfil?> signInWithEmail(String email, String password);
  Future<UsuarioPerfil?> signUpWithEmail(String email, String password, String nombre, String rol);
  Future<void> signOut();
  Future<UsuarioPerfil?> getCurrentUser();
  Stream<UsuarioPerfil?> get onAuthStateChanges;
  Future<void> deleteAccount();
}
