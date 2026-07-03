abstract class AuthEvent {}

class AppStarted extends AuthEvent {}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;
  SignInRequested({required this.email, required this.password});
}

class SignOutRequested extends AuthEvent {}
