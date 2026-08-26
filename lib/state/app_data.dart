import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'index_cubit.dart';
import 'products_cubit.dart';
import 'receipts_cubit.dart';

/// Fiş eklendi ya da silindi, bir eşleşme onaylandı — sekmelerdeki veri
/// bayatladı.
///
/// Eskiden global bir `dataChanged` bildiricisi vardı ve onu dinleyen her
/// AsyncView kendini tazeliyordu. Kimin neyi dinlediği görünmüyordu; burada
/// hangi cubit'lerin tazelendiği açıkça yazıyor.
///
/// [silent] veriliyor: ekranlar yükleniyor durumuna düşüp içeriği bir anlığına
/// boşaltmasın, eldeki veri yenisi gelene kadar kalsın.
///
/// Üçü birden bitince tamamlanan bir Future dönüyor: aşağı çekerek
/// tazeleme göstergesi ona bakarak toplanıyor. Çağıranların çoğu sonucu
/// beklemiyor, o da geçerli — bekleyen tek yer tazeleme göstergesi.
Future<void> refreshUserData(BuildContext context) => Future.wait([
  context.read<IndexCubit>().load(silent: true),
  context.read<ReceiptsCubit>().load(silent: true),
  context.read<ProductsCubit>().load(silent: true),
]);
