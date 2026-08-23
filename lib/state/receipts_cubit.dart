import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

/// Fiş listesi. Eşleşme kuyruğu da bunu dinliyor, yalnızca bekleyeni süzerek —
/// ayrı bir istek atmasının anlamı yok.
class ReceiptsCubit extends DataCubit<List<Receipt>> {
  ReceiptsCubit(this._repo);

  final Repository _repo;

  @override
  Future<List<Receipt>> fetch() => _repo.receipts();
}

/// Tek fişin ayrıntısı. Ekrana özel, yönlendirmeyle birlikte doğup ölüyor.
class ReceiptDetailCubit extends DataCubit<Receipt> {
  ReceiptDetailCubit(this._repo, this.receiptId);

  final Repository _repo;
  final String receiptId;

  @override
  Future<Receipt> fetch() => _repo.receipt(receiptId);
}
