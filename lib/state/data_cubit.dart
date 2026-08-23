import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';

/// Sunucudan veri çeken her ekranın üç hâli.
///
/// Mühürlü (sealed) sınıf: derleyici switch'te eksik durum bırakılmasına izin
/// vermiyor. Tek bir "loading + error + data" nesnesi olsaydı geçersiz
/// bileşimler mümkün olurdu — hem yükleniyor hem hatalı gibi.
sealed class DataState<T> {
  const DataState();
}

class DataLoading<T> extends DataState<T> {
  const DataLoading();
}

class DataFailure<T> extends DataState<T> {
  const DataFailure(this.message, {this.isUnauthorized = false});

  /// Sunucudan gelen, kullanıcıya gösterilebilir metin. Burada yeniden
  /// yorumlanmıyor.
  final String message;

  /// Oturum düştü — çağıranın giriş ekranına dönmesi gerekiyor.
  final bool isUnauthorized;
}

class DataReady<T> extends DataState<T> {
  const DataReady(this.value);
  final T value;
}

/// Tek bir veri kümesini yükleyen cubit'lerin ortak tabanı.
///
/// Ekranların çoğu aynı şeyi yapıyor: çağır, hata olursa mesajı göster,
/// olmazsa çiz. Bunu her cubit'te tekrar yazmak hem gürültü hem de hata
/// yakalamayı unutma fırsatı. Alt sınıflar yalnızca [fetch] yazıyor.
abstract class DataCubit<T> extends Cubit<DataState<T>> {
  DataCubit() : super(DataLoading<T>());

  /// Veriyi getirir. Hata yakalamak alt sınıfın işi değil.
  Future<T> fetch();

  /// Yeniden yükler. [silent] verildiğinde ekran yükleniyor durumuna
  /// düşmüyor — tazeleme sırasında mevcut veri ekranda kalsın diye.
  Future<void> load({bool silent = false}) async {
    if (!silent) emit(DataLoading<T>());
    try {
      final value = await fetch();
      if (!isClosed) emit(DataReady<T>(value));
    } on ApiException catch (e) {
      if (!isClosed) {
        emit(DataFailure<T>(e.message, isUnauthorized: e.isUnauthorized));
      }
    }
  }
}
