import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/api.dart';
import '../data/fmt.dart';
import '../data/repository.dart';
import '../state/app_data.dart';
import '../data/models.dart';
import '../state/receipts_cubit.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'match_queue_screen.dart';
import 'receipt_detail_screen.dart';

/// Aynı anda yalnızca bir satırın silme eylemi acik kalıyor.
///
/// iOS'un kendi davranışı bu ve sebebi var: iki satır birden acikken
/// kullanıcının hangisine bastığı gözle ayırt edilemiyor, silme de geri
/// alınamıyor.
final ValueNotifier<String?> _openRow = ValueNotifier<String?>(null);

/// Fişler sekmesi — endeksin ham malzemesi.
class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Fişler',
      reserveTabBar: true,
      trailing: Pressable(
        onTap: () => Navigator.of(context).push(MatchQueueScreen.route()),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(
            Glyph.check,
            size: 18,
            color: context.c.ink,
            stroke: 1.6,
          ),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: DataView<ReceiptsCubit, List<Receipt>>(
            isEmpty: (r) => r.isEmpty,
            empty: const EmptyState(
              title: 'Henüz fiş yok',
              body: 'İlk fişini ekleyince endeksin hesaplanmaya başlar.',
            ),
            builder: (context, receipts) {
              final total = receipts.fold<double>(0, (a, r) => a + r.total);
              return Padding(
                padding: kGutter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Lbl('${receipts.length} FİŞ · TOPLAM'),
                    const SizedBox(height: 6),
                    Text(Fmt.money(total), style: T.display),
                    const SizedBox(height: 16),
                    const Hairline(),
                    const SizedBox(height: 4),
                    for (final r in receipts)
                      // Anahtar fişin kimliğinden: bir satır silinince
                      // kalanlar yukarı kayıyor ve anahtarsız eşleştirmede
                      // Flutter durumu KONUMA göre tutuyordu — silinen
                      // satırın açık kalmış silme alanı, yerine geçen fişin
                      // üstünde beliriyordu.
                      _SwipeToDelete(
                        key: ValueKey(r.id),
                        receipt: r,
                        openRow: _openRow,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Sola kaydırınca altından silme eylemi çıkan fiş satırı.
///
/// Önce kaydırmanın kendisi siliyordu ve onay ayrı bir uyarı penceresinden
/// isteniyordu. İki sorun vardı: parmak henüz ekrandayken satır gidiyor,
/// ve gelen pencere kaydırmayla ilgisiz bir yerde açılıyordu — kullanıcı
/// neyi onayladığını satırdan kopuk okuyordu.
///
/// Şimdi kaydırma hiçbir şey silmiyor, yalnızca satırın altındaki kırmızı
/// alanı açıyor. Silme o alana dokununca oluyor. Onay ayrı bir adım değil,
/// hareketin kendisi: kaydır, sonra bas. İkisi de kasıtlı, ikisi de satırın
/// üstünde.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    super.key,
    required this.receipt,
    required this.openRow,
  });

  final Receipt receipt;

  /// Listedeki acik satır. Başkası açılınca bu kapanıyor.
  final ValueNotifier<String?> openRow;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  /// Satırın genişliğinin ne kadarını silme alanı kaplıyor.
  static const _actionFraction = .30;

  /// Kaydırmanın acik sayılması için gereken oran; hız bunu geçersiz kılıyor.
  static const _openThreshold = .5;

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  double _actionWidth = 0;

  bool get _isOpen => _slide.value > 0;

  @override
  void initState() {
    super.initState();
    widget.openRow.addListener(_onOpenRowChanged);
  }

  @override
  void dispose() {
    widget.openRow.removeListener(_onOpenRowChanged);
    _slide.dispose();
    super.dispose();
  }

  void _onOpenRowChanged() {
    if (widget.openRow.value != widget.receipt.id && _isOpen) _close();
  }

  void _open() {
    widget.openRow.value = widget.receipt.id;
    _slide.animateTo(1, curve: Curves.easeOutCubic);
  }

  void _close() {
    if (widget.openRow.value == widget.receipt.id) {
      widget.openRow.value = null;
    }
    _slide.animateTo(0, curve: Curves.easeOutCubic);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_actionWidth <= 0) return;
    _slide.value = (_slide.value - d.primaryDelta! / _actionWidth).clamp(0, 1);
  }

  void _onDragEnd(DragEndDetails d) {
    // Hızlı bir savurma yarıyı geçmese de açıyor; parmak yavaşsa konum
    // belirliyor.
    final v = d.primaryVelocity ?? 0;
    if (v < -320) return _open();
    if (v > 320) return _close();
    _slide.value > _openThreshold ? _open() : _close();
  }

  /// Satıra dokunmak acikken kapatıyor, kapalıyken fişi açıyor.
  ///
  /// Açık satırın kendisi "kapat" düğmesi: kullanıcı vazgeçtiğinde geri
  /// kaydırmak zorunda kalmasın.
  void _onRowTap() {
    if (_isOpen) {
      _close();
      return;
    }
    Navigator.of(context).push(ReceiptDetailScreen.route(widget.receipt.id));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _actionWidth = box.maxWidth * _actionFraction;

        return GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) {
              final acik = _actionWidth * _slide.value;
              return SizedBox(
                width: box.maxWidth,
                child: Stack(
                  children: [
                    // Satır kaymıyor, daralıyor.
                    //
                    // Kaydırmak platformun alışkanlığı ama burada işe
                    // yaramıyor: silme alanı satırın %30'u ve satır o kadar
                    // sola kayınca market adı ekranın solundan tamamen
                    // çıkıyor — kullanıcı tam da silmeye basacakken neyi
                    // sildiğini göremiyor. Daralınca ad yerinde kalıyor,
                    // tutar da sağ kenara yapışık geliyor.
                    //
                    // Konumlanmamış tek çocuk bu: yığının yüksekliğini
                    // satırın kendisi veriyor.
                    SizedBox(
                      width: box.maxWidth - acik,
                      child: ClipRect(child: child),
                    ),
                    // Kapalıyken hiç kurulmuyor: sıfır genişlikte de olsa
                    // ağaçta durursa "Sil" dokunulabilir ve okunabilir
                    // kalıyor — ekranda görünmediği hâlde.
                    if (acik > 0)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: acik,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: _actionWidth,
                            maxWidth: _actionWidth,
                            child: _DeleteAction(onTap: () => _delete(context)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            child: Pressable(
              onTap: _onRowTap,
              child: LedgerRow(
                name: widget.receipt.merchant,
                sub:
                    '${Fmt.dayMonth(widget.receipt.date)} · '
                    '${widget.receipt.itemCount} ÜRÜN'
                    '${widget.receipt.pendingCount > 0 ? ' · ${widget.receipt.pendingCount} EŞLEŞME' : ''}',
                amount: Fmt.money(widget.receipt.total),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context) async {
    final repo = context.read<Repository>();
    final messenger = ScaffoldMessenger.of(context);
    final r = widget.receipt;
    _close();

    try {
      await repo.deleteReceipt(r.id);
      if (context.mounted) refreshUserData(context);
      // Silinen fiş adıyla yazılıyor: işlem geri alınamıyor ve kullanıcının
      // hangisinin gittiğini sonradan görebilmesi tek güvencesi.
      messenger.showSnackBar(
        _snack('${r.merchant} · ${Fmt.dayMonth(r.date)} silindi'),
      );
    } on ApiException catch (e) {
      // Silme başarısızsa liste bayat kalmasın; fiş yerinde duruyor.
      if (context.mounted) refreshUserData(context);
      messenger.showSnackBar(_snack(e.message));
    }
  }

  SnackBar _snack(String text) => SnackBar(
    backgroundColor: context.c.ink,
    behavior: SnackBarBehavior.floating,
    content: Text(
      text,
      style: TextStyle(fontSize: 12.5, color: context.c.card),
    ),
  );
}

/// Satırın yanından açılan silme alanı.
///
/// Genişliği satırın %30'u: parmakla rahat vurulacak kadar büyük, satırın
/// kimliğini (market, tarih, tutar) sıkıştırmayacak kadar dar — kullanıcı
/// neyi sildiğini basarken hâlâ görüyor.
///
/// Kenardan kenara keskin bir blok değil, yuvarlatılmış bir kart: listenin
/// geri kalanı da öyle ve keskin dikdörtgen satırdan çok "uyarı bandı" gibi
/// duruyordu.
class _DeleteAction extends StatelessWidget {
  const _DeleteAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // Soldaki boşluk hem yumuşatıyor hem işlevsel: satır daralınca tutar
        // tam kırmızının dibine geliyor ve "224,00" okunamaz hâle geliyordu.
        margin: const EdgeInsets.fromLTRB(12, 4, 0, 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.c.hot,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Sil',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.c.card,
          ),
        ),
      ),
    );
  }
}
