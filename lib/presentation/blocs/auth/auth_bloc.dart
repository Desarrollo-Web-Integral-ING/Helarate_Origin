import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<SignInRequested>(_onSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
    on<ProfileUpdated>(_onProfileUpdated);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      print('Error al arrancar AuthBloc: $e');
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInRequested(
      SignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.signInWithEmail(
        event.email.trim(),
        event.password,
      );
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(AuthFailure('Las credenciales proporcionadas no son válidas.'));
      }
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('Invalid login credentials')) {
        errMsg = 'Correo o contraseña incorrectos.';
      } else if (errMsg.contains('network')) {
        errMsg = 'Error de conexión. Verifica tu internet.';
      } else {
        errMsg = errMsg.replaceAll('Exception: ', '');
      }
      emit(AuthFailure(errMsg));
    }
  }

  Future<void> _onSignOutRequested(
      SignOutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure('No se pudo cerrar la sesión: $e'));
    }
  }

  Future<void> _onDeleteAccountRequested(
      DeleteAccountRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.deleteAccount();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure('No se pudo eliminar la cuenta: $e'));
    }
  }

  // Sincroniza el perfil ya actualizado (Rectificación ARCO) sin pasar por
  // AuthLoading, para no desmontar MainNavigation/PerfilScreen.
  void _onProfileUpdated(ProfileUpdated event, Emitter<AuthState> emit) {
    emit(Authenticated(event.usuario));
  }
}
