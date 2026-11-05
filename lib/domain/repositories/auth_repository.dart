import '../models/usuario_perfil.dart';
import '../models/tenant_model.dart';

abstract class AuthRepository {
  Future<UsuarioPerfil?> signInWithEmail(String email, String password);
  Future<UsuarioPerfil?> signUpWithEmail(
      String email, String password, String nombre, String rol);
  Future<UsuarioPerfil?> signUpNewBusiness(String email, String password, String nombre, String empresa);
  Future<void> signOut();
  Future<UsuarioPerfil?> getCurrentUser();
  Stream<UsuarioPerfil?> get onAuthStateChanges;
  Future<void> deleteAccount();

  /// Derecho de Rectificación (ARCO): actualiza el nombre del perfil
  /// autenticado en Supabase y devuelve el perfil ya actualizado.
  Future<UsuarioPerfil> updateProfile(String nombre);

  /// Actualizar avatar y estilo de avatar del usuario (DiceBear)
  Future<UsuarioPerfil> updateAvatar(String style, String seed);

  /// Guarda (una sola vez) la aceptación del Aviso de Privacidad del usuario
  /// autenticado y devuelve el perfil actualizado.
  Future<UsuarioPerfil> acceptPrivacyNotice(String version);

  /// Obtener datos y personalización del tenant / empresa
  Future<TenantModel?> getTenant(String tenantId);

  /// Actualizar datos y personalización del tenant
  Future<TenantModel> updateTenant(TenantModel tenant);
}
