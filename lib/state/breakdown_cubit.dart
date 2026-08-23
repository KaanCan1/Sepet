import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

/// Kırılımın hangi eksende okunduğu.
enum BreakdownAxis {
  category('Kategori', 'KATEGORİ'),
  brand('Marka', 'MARKA');

  const BreakdownAxis(this.tab, this.label);

  final String tab;
  final String label;
}

/// Kategori ve marka kırılımı.
///
/// Eksen seçimi de burada: ekranın setState'iyle tutulduğunda hangi verinin
/// hangi eksene ait olduğu iki ayrı yerde saklanıyordu ve sekme değişince
/// eski liste bir kare boyunca yeni başlığın altında görünüyordu.
class BreakdownCubit extends DataCubit<List<Breakdown>> {
  BreakdownCubit(this._repo);

  final Repository _repo;

  BreakdownAxis _axis = BreakdownAxis.category;
  BreakdownAxis get axis => _axis;

  @override
  Future<List<Breakdown>> fetch() => switch (_axis) {
    BreakdownAxis.category => _repo.indexByCategory(),
    BreakdownAxis.brand => _repo.indexByBrand(),
  };

  Future<void> select(BreakdownAxis axis) async {
    if (axis == _axis) return;
    _axis = axis;
    await load();
  }
}
