import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

/// Ana ekranın tek seferde ihtiyaç duyduğu her şey.
///
/// Eskiden ekran bir kayıt (record) yükleyip `data.$1`, `data.$2` diye
/// okuyordu; adı olmayan alanlar okunmuyordu.
class IndexHome {
  const IndexHome({required this.snapshot, required this.receipts});

  final IndexSnapshot snapshot;
  final List<Receipt> receipts;

  bool get isEmpty => snapshot.isEmpty;
}

/// Endeks manşeti, serisi ve son fişler. Profil ekranı da bunu dinliyor —
/// iki yerde ayrı yüklenirse biri bayatlıyordu.
class IndexCubit extends DataCubit<IndexHome> {
  IndexCubit(this._repo);

  final Repository _repo;

  @override
  Future<IndexHome> fetch() async => IndexHome(
    snapshot: await _repo.index(),
    receipts: await _repo.receipts(),
  );
}
