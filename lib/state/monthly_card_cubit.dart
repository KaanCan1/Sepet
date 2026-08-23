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
  Future<MonthlyCard> fetch() async => MonthlyCard(
    snapshot: await _repo.index(),
    movers: await _repo.movers(),
    receipts: await _repo.receipts(),
  );
}
