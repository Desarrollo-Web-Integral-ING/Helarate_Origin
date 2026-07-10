import '../../../domain/models/usuario_perfil.dart';

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
