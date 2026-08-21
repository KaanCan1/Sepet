import 'package:flutter/widgets.dart';

import 'api.dart';
import 'auth_store.dart';
import 'repository.dart';
import 'session.dart';

/// Uygulama genelindeki tekil bağımlılıklar. Testler bunu kendi sahteleriyle
/// sarmalayabilsin diye InheritedWidget.
class AppScope extends InheritedWidget {
  factory AppScope({
    Key? key,
    Api? api,
    AuthStore? authStore,
    required Widget child,
  }) => AppScope._(
    api ?? Api(),
    authStore ?? const SecureAuthStore(),
    key: key,
    child: child,
  );

  AppScope._(this.api, this.authStore, {super.key, required super.child})
    : repository = Repository(api);

  final Api api;
  final AuthStore authStore;
  final Repository repository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope bulunamadı');
    return scope!;
  }

  static Repository repoOf(BuildContext context) => of(context).repository;

  /// Jetonu diskten okuyup istemciye yerleştirir. Açılışta bir kez çağrılır.
  Future<bool> restoreSession() async {
    final token = await authStore.read();
    if (token == null) return false;
    api.setToken(token);
    try {
      // Jeton hâlâ geçerli mi? Süresi dolmuşsa giriş ekranına düşülmeli.
      await repository.index();
      session.value = const Session(provider: AuthProvider.email);
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
        return false;
      }
      // Ağ hatası jetonu geçersiz kılmaz — oturumu koru.
      session.value = const Session(provider: AuthProvider.email);
      return true;
    }
  }

  Future<void> signIn({
    required String email,
    required AuthProvider provider,
    String? name,
  }) async {
    final res = await api.post('/auth/dev-login', {
      'email': email,
    }) as Map<String, dynamic>;
    final token = res['token'] as String;
    api.setToken(token);
    await authStore.write(token);
    session.value = Session(email: email, name: name, provider: provider);
  }

  Future<void> signOut() async {
    api.setToken(null);
    await authStore.clear();
    session.value = null;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api || repository != oldWidget.repository;
}
