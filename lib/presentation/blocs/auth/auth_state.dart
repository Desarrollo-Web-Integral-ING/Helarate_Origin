import '../../../domain/models/usuario_perfil.dart';
import '../../../domain/models/tenant_model.dart';

abstract class AuthState {
  final bool isDarkMode;
  const AuthState({this.isDarkMode = false});
}

class AuthInitial extends AuthState {
  const AuthInitial({super.isDarkMode = false});
}

class AuthLoading extends AuthState {
  const AuthLoading({super.isDarkMode = false});
}

class Authenticated extends AuthState {
  final UsuarioPerfil usuario;
  final TenantModel? tenant;

  const Authenticated(this.usuario, {this.tenant, super.isDarkMode = false});

  Authenticated copyWith({
    UsuarioPerfil? usuario,
    TenantModel? tenant,
    bool? isDarkMode,
  }) {
    return Authenticated(
      usuario ?? this.usuario,
      tenant: tenant ?? this.tenant,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

class Unauthenticated extends AuthState {
  const Unauthenticated({super.isDarkMode = false});
}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message, {super.isDarkMode = false});
}
