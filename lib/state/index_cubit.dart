import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

/// Ana ekranın tek seferde ihtiyaç duyduğu her şey.
///
/// Eskiden ekran bir kayıt (record) yükleyip `data.$1`, `data.$2` diye
/// okuyordu; adı olmayan alanlar okunmuyordu.
class IndexHome {
  const IndexHome({
    required this.snapshot,
    required this.receipts,
    required this.basket,
  });

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;

  /// Endeks olgunlaşana kadar ekranın söyleyebildiği tek somut şey.
  final BasketCompare basket;

  bool get isEmpty => snapshot.isEmpty;

  /// Endekse girmeyen kalem sayısı. Eşleşmeyen satır sessizce kapsam
  /// dışında kalıyordu — sayı doğru ama eksik bir sepetten geliyordu ve
  /// bunu söyleyen hiçbir şey yoktu.
  int get pendingLines => receipts.fold(0, (a, r) => a + r.pendingCount);
}

/// Endeks manşeti, serisi ve son fişler. Profil ekranı da bunu dinliyor —
/// iki yerde ayrı yüklenirse biri bayatlıyordu.
class IndexCubit extends DataCubit<IndexHome> {
  IndexCubit(this._repo);

  final Repository _repo;

  /// Üç istek birbirini beklemiyor: sıralı yazıldığında ekranın açılması üç
  /// gidiş-dönüşün toplamı kadar sürüyordu, oysa aralarında bağımlılık yok.
  ///
  /// Kayıt (record) sözdizimindeki `.wait` yerine [Future.wait]: o, hataları
  /// `ParallelWaitError` içinde sarmalıyor ve DataCubit'in yakaladığı
  /// `ApiException` görünmez oluyor — sunucu hatası ekranda hata durumuna
  /// düşmek yerine yakalanmamış istisnaya dönüşüyordu.
  @override
  Future<IndexHome> fetch() async {
    final r = await Future.wait<dynamic>([
      _repo.index(),
      _repo.receipts(),
      _repo.basketCompare(),
    ]);
    return IndexHome(
      snapshot: r[0] as IndexSnapshot,
      receipts: r[1] as List<Receipt>,
      basket: r[2] as BasketCompare,
    );
  }
}
