import '../../../domain/models/usuario_perfil.dart';
import '../../../domain/models/tenant_model.dart';

abstract class AuthEvent {}

class AppStarted extends AuthEvent {}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;
  SignInRequested({required this.email, required this.password});
}

class SignOutRequested extends AuthEvent {}

class DeleteAccountRequested extends AuthEvent {}

/// Emitido cuando el perfil ya fue actualizado (Derecho de Rectificación,
/// ARCO) para sincronizar el AuthBloc sin pasar por un estado de carga
/// global que saque al usuario de PerfilScreen.
class ProfileUpdated extends AuthEvent {
  final UsuarioPerfil usuario;
  ProfileUpdated(this.usuario);
}

/// Actualización de los datos/branding de la empresa o tenant
class TenantUpdated extends AuthEvent {
  final TenantModel tenant;
  TenantUpdated(this.tenant);
}

/// Alternar modo oscuro de manera instantánea con un clic
class ToggleThemeRequested extends AuthEvent {}

/// Actualizar la personalización e identidad de marca del tenant
class UpdateTenantRequested extends AuthEvent {
  final TenantModel tenant;
  UpdateTenantRequested(this.tenant);
}

/// El usuario aceptó el Aviso de Privacidad (se guarda una sola vez).
class PrivacyAccepted extends AuthEvent {
  final String version;
  PrivacyAccepted(this.version);
}
