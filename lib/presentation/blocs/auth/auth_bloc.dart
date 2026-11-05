import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/models/tenant_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  static const String _prefDarkModeKey = 'app_dark_mode';

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<SignInRequested>(_onSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<DeleteAccountRequested>(_onDeleteAccountRequested);
    on<ProfileUpdated>(_onProfileUpdated);
    on<TenantUpdated>(_onTenantUpdated);
    on<ToggleThemeRequested>(_onToggleThemeRequested);
    on<UpdateTenantRequested>(_onUpdateTenantRequested);
    on<PrivacyAccepted>(_onPrivacyAccepted);
  }

  Future<void> _onPrivacyAccepted(
      PrivacyAccepted event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! Authenticated) return;
    try {
      final perfil = await authRepository.acceptPrivacyNotice(event.version);
      emit(current.copyWith(usuario: current.usuario.copyWith(aceptadoAvisoAt: perfil.aceptadoAvisoAt ?? DateTime.now())));
    } catch (e) {
      debugPrint('Error guardando aceptación del aviso: $e');
      // No bloquear al usuario: se marca como aceptado en esta sesión.
      emit(current.copyWith(usuario: current.usuario.copyWith(aceptadoAvisoAt: DateTime.now())));
    }
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localDarkMode = prefs.getBool(_prefDarkModeKey) ?? false; // Default: modo claro

      final user = await authRepository.getCurrentUser();
      if (user != null) {
        TenantModel? tenant;
        if (user.tenantId != null) {
          tenant = await authRepository.getTenant(user.tenantId!);
        }
        // Si el tenant tiene preferencia de tema definida, sincronizar con la persistencia local
        final activeDark = tenant?.modoOscuro ?? localDarkMode;
        await prefs.setBool(_prefDarkModeKey, activeDark);

        emit(Authenticated(user, tenant: tenant, isDarkMode: activeDark));
      } else {
        emit(Unauthenticated(isDarkMode: localDarkMode));
      }
    } catch (e) {
      print('Error al arrancar AuthBloc: $e');
      final prefs = await SharedPreferences.getInstance();
      final localDarkMode = prefs.getBool(_prefDarkModeKey) ?? false;
      emit(Unauthenticated(isDarkMode: localDarkMode));
    }
  }

  Future<void> _onSignInRequested(
      SignInRequested event, Emitter<AuthState> emit) async {
    final currentMode = state.isDarkMode;
    emit(AuthLoading(isDarkMode: currentMode));
    try {
      final user = await authRepository.signInWithEmail(
        event.email.trim(),
        event.password,
      );
      if (user != null) {
        TenantModel? tenant;
        if (user.tenantId != null) {
          tenant = await authRepository.getTenant(user.tenantId!);
        }
        final finalDark = tenant?.modoOscuro ?? currentMode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefDarkModeKey, finalDark);

        emit(Authenticated(user, tenant: tenant, isDarkMode: finalDark));
      } else {
        emit(AuthFailure('Las credenciales proporcionadas no son válidas.', isDarkMode: currentMode));
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
      emit(AuthFailure(errMsg, isDarkMode: currentMode));
    }
  }

  Future<void> _onSignOutRequested(
      SignOutRequested event, Emitter<AuthState> emit) async {
    final currentMode = state.isDarkMode;
    emit(AuthLoading(isDarkMode: currentMode));
    try {
      await authRepository.signOut();
      emit(Unauthenticated(isDarkMode: currentMode));
    } catch (e) {
      emit(AuthFailure('No se pudo cerrar la sesión: $e', isDarkMode: currentMode));
    }
  }

  Future<void> _onDeleteAccountRequested(
      DeleteAccountRequested event, Emitter<AuthState> emit) async {
    final currentMode = state.isDarkMode;
    emit(AuthLoading(isDarkMode: currentMode));
    try {
      await authRepository.deleteAccount();
      emit(Unauthenticated(isDarkMode: currentMode));
    } catch (e) {
      emit(AuthFailure('No se pudo eliminar la cuenta: $e', isDarkMode: currentMode));
    }
  }

  void _onProfileUpdated(ProfileUpdated event, Emitter<AuthState> emit) {
    final current = state;
    if (current is Authenticated) {
      emit(current.copyWith(usuario: event.usuario));
    }
  }

  void _onTenantUpdated(TenantUpdated event, Emitter<AuthState> emit) {
    final current = state;
    if (current is Authenticated) {
      emit(current.copyWith(tenant: event.tenant, isDarkMode: event.tenant.modoOscuro));
    }
  }

  Future<void> _onToggleThemeRequested(
      ToggleThemeRequested event, Emitter<AuthState> emit) async {
    final newMode = !state.isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDarkModeKey, newMode);

    final current = state;
    if (current is Authenticated) {
      TenantModel? updatedTenant;
      if (current.tenant != null) {
        updatedTenant = current.tenant!.copyWith(modoOscuro: newMode);
      }
      emit(current.copyWith(tenant: updatedTenant, isDarkMode: newMode));

      if (updatedTenant != null) {
        try {
          await authRepository.updateTenant(updatedTenant);
        } catch (e) {
          debugPrint('Error guardando preferencia de tema en servidor: $e');
        }
      }
    } else {
      if (current is Unauthenticated) {
        emit(Unauthenticated(isDarkMode: newMode));
      } else if (current is AuthFailure) {
        emit(AuthFailure(current.message, isDarkMode: newMode));
      } else {
        emit(Unauthenticated(isDarkMode: newMode));
      }
    }
  }

  Future<void> _onUpdateTenantRequested(
      UpdateTenantRequested event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is Authenticated) {
      emit(current.copyWith(tenant: event.tenant, isDarkMode: event.tenant.modoOscuro));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDarkModeKey, event.tenant.modoOscuro);
      try {
        final result = await authRepository.updateTenant(event.tenant);
        emit(current.copyWith(tenant: result, isDarkMode: result.modoOscuro));
      } catch (e) {
        debugPrint('Error actualizando tenant: $e');
      }
    }
  }
}
