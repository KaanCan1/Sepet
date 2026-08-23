import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';
import '../data/auth_store.dart';
import '../data/repository.dart';
import '../data/session.dart';

/// Oturumun üç hâli. "Bilinmiyor" ayrı bir durum: açılışta jeton diskten
/// okunurken karşılama ekranını bir an gösterip sonra kabuğa atlamak
/// göz tırmalıyordu.
sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session);
  final Session session;
}

/// Kimlik ve oturum. Eskiden global bir ValueNotifier ve AppScope üzerindeki
/// serbest fonksiyonlardı; ikisi de widget ağacının dışında duruyordu ve
/// test etmek için uygulamayı ayağa kaldırmak gerekiyordu.
class AuthCubit extends Cubit<AuthState> {
  // Konumsal: adlandırılmış parametreler Dart'ta private olamıyor, dolayısıyla
  // this._api yazılamıyordu ve üç alan elle atanıyordu. Türler birbirinden
  // ayırt edilebilir olduğu için sıra karışma riski yok.
  AuthCubit(this._api, this._repo, this._store) : super(const AuthUnknown());

  final Api _api;
  final Repository _repo;
  final AuthStore _store;

  Session? get session => switch (state) {
    AuthSignedIn(:final session) => session,
    _ => null,
  };

  /// Açılışta bir kez: jetonu diskten okuyup istemciye yerleştirir.
  Future<void> restore() async {
    final token = await _store.read();
    if (token == null) {
      emit(const AuthSignedOut());
      return;
    }
    _api.setToken(token);
    try {
      // Jeton hâlâ geçerli mi? Süresi dolmuşsa ya da hesap silinmişse
      // giriş ekranına düşülmeli.
      await _repo.index();
      emit(const AuthSignedIn(Session(provider: AuthProvider.email)));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
        return;
      }
      // Ağ hatası jetonu geçersiz kılmaz — oturumu koru.
      emit(const AuthSignedIn(Session(provider: AuthProvider.email)));
    }
  }

  Future<void> signIn({
    required String email,
    required AuthProvider provider,
    String? name,
  }) async {
    final res = await _api.post('/auth/dev-login', {
      'email': email,
    }) as Map<String, dynamic>;
    final token = res['token'] as String;
    _api.setToken(token);
    await _store.write(token);
    emit(AuthSignedIn(Session(email: email, name: name, provider: provider)));
  }

  Future<void> signOut() async {
    _api.setToken(null);
    await _store.clear();
    emit(const AuthSignedOut());
  }

  /// KVKK açık rızaları. İkisi de isteğe bağlı, varsayılan kapalı.
  void setConsents({bool? aggregate, bool? marketing}) {
    final current = session;
    if (current == null) return;
    emit(
      AuthSignedIn(
        current.copyWith(
          consentAggregate: aggregate,
          consentMarketing: marketing,
        ),
      ),
    );
  }

  /// Hesabı sunucudan siler ve oturumu kapatır.
  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    await signOut();
  }
}
