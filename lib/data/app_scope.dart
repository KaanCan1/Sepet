import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/auth_cubit.dart';
import '../state/index_cubit.dart';
import '../state/products_cubit.dart';
import '../state/receipts_cubit.dart';
import 'api.dart';
import 'auth_store.dart';
import 'notifications.dart';
import 'repository.dart';

/// Uygulama genelindeki bağımlılıkları ve uzun ömürlü cubit'leri kurar.
///
/// Eskiden bu bir InheritedWidget'tı ve oturum açma/kapatma mantığını da
/// kendisi taşıyordu — yani widget ağacının bir düğümü iş kuralı
/// çalıştırıyordu. Artık yalnızca kablolama: iş AuthCubit'te.
///
/// Sekme ekranlarının cubit'leri burada, kabuğun ÜSTÜNDE duruyor. Sebebi
/// somut: fiş eklendiğinde endeks de fiş listesi de bayatlıyor; ikisi ekrana
/// bağlı olsaydı sekme değiştirmeden tazelenemezlerdi. Ayrıntı ekranlarının
/// cubit'leri ise yönlendirmeyle birlikte doğup ölüyor.
class AppScope extends StatelessWidget {
  AppScope({
    super.key,
    Api? api,
    AuthStore? authStore,
    MonthlyReminder? reminder,
    required this.child,
  }) : api = api ?? Api(),
       authStore = authStore ?? const SecureAuthStore(),
       reminder = reminder ?? LocalMonthlyReminder();

  final Api api;
  final AuthStore authStore;
  final MonthlyReminder reminder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = Repository(api);

    return RepositoryProvider.value(
      value: repository,
      child: RepositoryProvider<MonthlyReminder>.value(
        value: reminder,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AuthCubit(api, repository, authStore)..restore(),
            ),
            BlocProvider(create: (_) => IndexCubit(repository)),
            BlocProvider(create: (_) => ReceiptsCubit(repository)),
            BlocProvider(create: (_) => ProductsCubit(repository)),
          ],
          child: child,
        ),
      ),
    );
  }
}
