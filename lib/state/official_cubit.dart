import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

/// Resmî ve bağımsız seriler; elle giriliyor.
class OfficialCubit extends DataCubit<List<OfficialSeries>> {
  OfficialCubit(this._repo);

  final Repository _repo;

  @override
  Future<List<OfficialSeries>> fetch() => _repo.officialSeries();

  Future<void> save({
    required String code,
    required DateTime month,
    required double yoyPct,
  }) async {
    await _repo.saveOfficial(code: code, month: month, yoyPct: yoyPct);
    // Sessiz değil: liste yeniden sıralanıyor, kısa bir yükleniyor hâli
    // kullanıcıya kaydın işlendiğini gösteriyor.
    await load();
  }

  /// TCMB EVDS'ten çeker. Anahtar sunucuda tanımlı değilse ApiException
  /// atıyor ve ekran elle giriş yolunu göstermeye devam ediyor.
  Future<int> refreshFromSource() async {
    final written = await _repo.refreshOfficial();
    await load();
    return written;
  }

  Future<void> remove({required String code, required DateTime month}) async {
    await _repo.deleteOfficial(code: code, month: month);
    await load();
  }
}
