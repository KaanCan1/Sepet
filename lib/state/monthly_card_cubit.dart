import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

/// Paylaşılabilir aylık kartın verisi.
class MonthlyCard {
  const MonthlyCard({
    required this.snapshot,
    required this.movers,
    required this.receipts,
  });

  final IndexSnapshot snapshot;
  final List<Mover> movers;
  final List<Receipt> receipts;
}

class MonthlyCardCubit extends DataCubit<MonthlyCard> {
  MonthlyCardCubit(this._repo);

  final Repository _repo;

  @override
  Future<MonthlyCard> fetch() async {
    final r = await Future.wait<dynamic>([
      _repo.index(),
      _repo.movers(),
      _repo.receipts(),
    ]);
    return MonthlyCard(
      snapshot: r[0] as IndexSnapshot,
      movers: r[1] as List<Mover>,
      receipts: r[2] as List<Receipt>,
    );
  }
}
