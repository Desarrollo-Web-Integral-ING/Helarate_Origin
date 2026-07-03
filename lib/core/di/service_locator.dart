import 'package:get_it/get_it.dart';
import '../../domain/repositories/insumo_repository.dart';
import '../../domain/repositories/venta_repository.dart';
import '../../domain/repositories/gasto_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/supabase_insumo_repository.dart';
import '../../data/repositories/supabase_venta_repository.dart';
import '../../data/repositories/supabase_gasto_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<InsumoRepository>(() => SupabaseInsumoRepository());
  getIt.registerLazySingleton<VentaRepository>(() => SupabaseVentaRepository());
  getIt.registerLazySingleton<GastoRepository>(() => SupabaseGastoRepository());
  getIt.registerLazySingleton<AuthRepository>(() => SupabaseAuthRepository());
}
