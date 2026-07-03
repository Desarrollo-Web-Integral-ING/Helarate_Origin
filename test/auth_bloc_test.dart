import 'package:flutter_test/flutter_test.dart';
import 'package:nevero_app/domain/models/usuario_perfil.dart';
import 'package:nevero_app/domain/repositories/auth_repository.dart';
import 'package:nevero_app/presentation/blocs/auth/auth_bloc.dart';
import 'package:nevero_app/presentation/blocs/auth/auth_event.dart';
import 'package:nevero_app/presentation/blocs/auth/auth_state.dart';

class FakeAuthRepository implements AuthRepository {
  UsuarioPerfil? mockUser;
  bool shouldThrow = false;

  @override
  Future<UsuarioPerfil?> getCurrentUser() async {
    if (shouldThrow) throw Exception('Database error');
    return mockUser;
  }

  @override
  Stream<UsuarioPerfil?> get onAuthStateChanges => Stream.value(mockUser);

  @override
  Future<UsuarioPerfil?> signInWithEmail(String email, String password) async {
    if (shouldThrow) throw Exception('Invalid login credentials');
    return mockUser;
  }

  @override
  Future<UsuarioPerfil?> signUpWithEmail(
    String email,
    String password,
    String nombre,
    String rol,
  ) async {
    return mockUser;
  }

  @override
  Future<void> signOut() async {
    mockUser = null;
  }
}

void main() {
  late FakeAuthRepository fakeAuthRepository;
  late AuthBloc authBloc;

  setUp(() {
    fakeAuthRepository = FakeAuthRepository();
    authBloc = AuthBloc(authRepository: fakeAuthRepository);
  });

  tearDown(() {
    authBloc.close();
  });

  test('El estado inicial debe ser AuthInitial', () {
    expect(authBloc.state, isA<AuthInitial>());
  });

  test('AppStarted emite Unauthenticated si no hay sesión activa', () async {
    fakeAuthRepository.mockUser = null;

    final expectedStates = [
      isA<AuthLoading>(),
      isA<Unauthenticated>(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));
    authBloc.add(AppStarted());
  });

  test('AppStarted emite Authenticated si hay una sesión activa', () async {
    fakeAuthRepository.mockUser = UsuarioPerfil(
      id: 'user123',
      nombre: 'Administrador',
      rol: 'dueño',
      createdAt: DateTime.now(),
    );

    final expectedStates = [
      isA<AuthLoading>(),
      isA<Authenticated>(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));
    authBloc.add(AppStarted());
  });

  test('SignInRequested emite Authenticated cuando el login es correcto', () async {
    fakeAuthRepository.mockUser = UsuarioPerfil(
      id: 'user123',
      nombre: 'Empleado 1',
      rol: 'empleado',
      createdAt: DateTime.now(),
    );

    final expectedStates = [
      isA<AuthLoading>(),
      isA<Authenticated>(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));
    authBloc.add(SignInRequested(email: 'test@neveria.com', password: 'password123'));
  });

  test('SignInRequested emite AuthFailure cuando falla el login', () async {
    fakeAuthRepository.shouldThrow = true;

    final expectedStates = [
      isA<AuthLoading>(),
      isA<AuthFailure>(),
    ];

    expectLater(authBloc.stream, emitsInOrder(expectedStates));
    authBloc.add(SignInRequested(email: 'wrong@neveria.com', password: 'wrongpassword'));
  });
}
