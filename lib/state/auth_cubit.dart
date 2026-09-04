import 'package:flutter/foundation.dart';
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

  /// Arka planda süren jeton doğrulaması. Yalnızca testler bekliyor;
  /// açılış yolu bilerek beklemiyor.
  @visibleForTesting
  Future<void>? verification;

  /// Açılışta bir kez: jetonu diskten okuyup istemciye yerleştirir.
  ///
  /// Jeton varsa oturum HEMEN açık sayılıyor ve doğrulama arka plana
  /// alınıyor. Eskiden burada `/index` beklenirdi ve o bitene kadar ekranda
  /// boş kâğıt zemin dururdu: Render ücretsiz katmanda uyuyan sunucu
  /// uyanana kadar bu bekleyiş 12 sn + 50 sn'lik iki denemeye kadar
  /// uzuyordu. Kullanıcının gördüğü şey bir dakikalık beyaz ekrandı,
  /// üstelik henüz hiçbir şey yanlış gitmemişken.
  ///
  /// İyimserlik bedava değil: süresi dolmuş jetonla kabuk bir an açılıp
  /// karşılama ekranına düşülüyor. Karşılığında açılış, Keychain okumasının
  /// süresine iniyor. Eski kod zaten ağ hatasında oturumu koruyordu —
  /// yani oturumu düşüren tek şey hâlâ 401.
  Future<void> restore() async {
    final token = await _store.read();
    if (token == null) {
      if (await _demoSignIn()) return;
      emit(const AuthSignedOut());
      return;
    }
    _api.setToken(token);
    emit(const AuthSignedIn(Session(provider: AuthProvider.email)));
    verification = _verify();
  }

  /// Jeton hâlâ geçerli mi? Süresi dolmuşsa ya da hesap silinmişse giriş
  /// ekranına düşülüyor. Sunucudan gelen e-posta da buradan alınıyor:
  /// onsuz yeniden açılışta profilde ad yerine "Hesabım" yazıyordu.
  Future<void> _verify() async {
    try {
      final session = await _repo.me();
      if (!isClosed) emit(AuthSignedIn(session));
    } on ApiException catch (e) {
      if (isClosed) return;
      // Ağ hatası jetonu geçersiz kılmaz — oturumu koru.
      if (e.isUnauthorized) await signOut();
    }
  }

  /// Mağaza görselleri için otomatik giriş. Derleme zamanı bayrağı boşsa
  /// hiçbir şey yapmıyor, yani normal derlemelerde bu kod ölü.
  ///
  /// Gerekçesi araç zinciri: goldie her akıştan önce uygulamayı verisi
  /// silinmiş hâlde kuruyor, dolayısıyla ekran görüntüsü alınacak her akış
  /// giriş ekranından başlıyor. E-postayı akış içinde yazdırmak da
  /// çalışmıyor — simülatör Türkçe klavye düzenini kullanıyor ve "@" karakteri
  /// "'" olarak giriyor.
  ///
  /// İki kilit birden: bayrak dolu OLACAK ve derleme hata ayıklama modunda
  /// OLACAK. Yayın derlemesinde bayrak verilse bile çalışmıyor.
  static const _demoEmail = String.fromEnvironment('SEPET_DEMO_EMAIL');

  Future<bool> _demoSignIn() async {
    if (!kDebugMode || _demoEmail.isEmpty) return false;
    try {
      await signIn(email: _demoEmail, provider: AuthProvider.email);
      return true;
    } on ApiException {
      // Sunucu yoksa ya da e-posta izinli listede değilse sessizce normal
      // akışa dön: karşılama ekranı görünür, kimse kilitlenmez.
      return false;
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
