import '../data/models.dart';
import '../data/repository.dart';
import 'data_cubit.dart';

class ProductsCubit extends DataCubit<List<Product>> {
  ProductsCubit(this._repo);

  final Repository _repo;

  @override
  Future<List<Product>> fetch() => _repo.products();
}

class ProductDetailCubit extends DataCubit<Product> {
  ProductDetailCubit(this._repo, this.productId);

  final Repository _repo;
  final String productId;

  @override
  Future<Product> fetch() => _repo.product(productId);
}
