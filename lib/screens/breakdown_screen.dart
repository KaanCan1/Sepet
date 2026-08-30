import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repository.dart';
import '../state/breakdown_cubit.dart';
import '../data/fmt.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import '../widgets/data_view.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';

/// 05 — Kırılım. Genel sayı "ne kadar" diyor; bu ekran "nereden" diyor.
///
/// Kategori ve marka serileri genel endeksin alt kalemleri DEĞİL: her biri
/// kendi kümesinde yeniden ağırlıklandırılıyor, toplandıklarında genel
/// endeksi vermezler. Alttaki not bunu söylüyor — aksi halde okuyan
/// yüzdeleri toplamaya kalkar.
class BreakdownScreen extends StatelessWidget {
  const BreakdownScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    builder: (context) => BlocProvider(
      create: (_) => BreakdownCubit(context.read<Repository>())..load(),
      child: const BreakdownScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<BreakdownCubit>();
    final axis = cubit.axis;

    return ScreenFrame(
      showTopBar: false,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: kGutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LargeTitle(
                  'Kırılım',
                  trailing: 'SON 12 AY',
                  onBack: () => Navigator.of(context).pop(),
                ),
                _AxisToggle(value: axis, onChanged: cubit.select),
                const SizedBox(height: 16),
                // Eksen de veri de cubit'te: seçim değişince yeni liste
                // gelene kadar eskisi yeni başlığın altında görünmüyor.
                DataView<BreakdownCubit, List<Breakdown>>(
                  isEmpty: (rows) => rows.isEmpty,
                  empty: EmptyState(
                    title: axis == BreakdownAxis.category
                        ? 'Kategori kırılımı için veri yok'
                        : 'Marka kırılımı için veri yok',
                    body: axis == BreakdownAxis.category
                        ? 'Bir kategorinin serisi için o kategoride en az iki '
                              'farklı ayda fiş gerekiyor.'
                        : 'Markalı ürünlerde en az iki farklı ayda fiş '
                              'gerekiyor. Kasada tartılan sebze ve meyvenin '
                              'markası olmadığı için bu listede yer almaz.',
                  ),
                  builder: (context, rows) => _List(axis: axis, rows: rows),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AxisToggle extends StatelessWidget {
  const _AxisToggle({required this.value, required this.onChanged});

  final BreakdownAxis value;
  final ValueChanged<BreakdownAxis> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Oluk `track`, seçili yarım `ink`. Eskiden oluk için çizgi rengine
    // alfa uygulanıyordu; çizgi rengi yarı saydama dönünce üst üste binip
    // koyu gri bir levhaya çıkıyordu.
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final axis in BreakdownAxis.values)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(axis),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: axis == value ? c.ink : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    axis.tab,
                    textAlign: TextAlign.center,
                    style: T.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: axis == value ? c.paper : c.faint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.axis, required this.rows});

  final BreakdownAxis axis;
  final List<Breakdown> rows;

  @override
  Widget build(BuildContext context) {
    final top = rows.first;
    final bottom = rows.last;
    final peak = rows.fold<double>(
      0,
      (a, r) => r.changePct.abs() > a ? r.changePct.abs() : a,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Lbl('EN ÇOK ARTAN ${axis.label}'),
        const SizedBox(height: 4),
        Text(top.name, style: T.display),
        const SizedBox(height: 2),
        Text(
          Fmt.signedPct1(top.changePct),
          style: TextStyle(
            fontFamily: F.mono,
            fontFamilyFallback: F.monoFallback,
            fontSize: 17,
            color: top.changePct >= 0 ? context.c.hot : context.c.ref,
          ),
        ),
        const SizedBox(height: 14),
        LineChart(
          height: 96,
          series: [
            ChartSeries(
              values: top.levels,
              color: context.c.ink,
              endDot: true,
              fill: context.c.ink.withValues(alpha: context.c.areaFade),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Hairline(),
        const SizedBox(height: 12),
        Lbl('TÜM ${axis.label}LER'),
        const SizedBox(height: 2),
        for (final (i, row) in rows.indexed)
          _Row(
            row: row,
            peak: peak,
            step: i,
            onTap: () =>
                Navigator.of(context).push(_DetailScreen.route(axis, row)),
          ),
        const SizedBox(height: 16),
        // Yüzdeler toplanabilir sanılmasın.
        Text(
          rows.length > 1
              ? 'Her ${axis.label.toLowerCase()} kendi içinde ayrı '
                    'hesaplanıyor: ağırlıklar o kümede yeniden dağıtılıyor. '
                    'Bu yüzden yüzdeler birbirine eklenmez ve toplamları '
                    'genel endeksi vermez. En çok artan ${top.name}, en az '
                    'artan ${bottom.name}.'
              : 'Tek bir ${axis.label.toLowerCase()} için seri var. '
                    'Karşılaştırma için birkaç ay daha fiş gerekiyor.',
          style: TextStyle(fontSize: 11, height: 1.5, color: context.c.muted),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.peak,
    required this.step,
    this.onTap,
  });

  final Breakdown row;

  /// Listedeki en büyük mutlak değişim — bar bunun oranında doluyor.
  final double peak;
  final int step;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Bar oranı listedeki en büyük değişime göre; renk kategoriden geliyor
    // ve satırdaki sayıyla aynı. İkisi aynı şeyi söylüyor.
    return StatRow(
      step: step,
      name: row.name,
      value: Fmt.signedPct1(row.changePct),
      ratio: peak == 0 ? 0 : row.changePct.abs() / peak,
      color: context.c.category[categoryIndex(row.name)],
      sub: '${row.series.length} AY',
      onTap: onTap,
    );
  }
}

/// Tek kategori ya da markanın serisi, ay ay.
class _DetailScreen extends StatelessWidget {
  const _DetailScreen({required this.axis, required this.row});

  final BreakdownAxis axis;
  final Breakdown row;

  static Route<void> route(BreakdownAxis axis, Breakdown row) =>
      CupertinoPageRoute(
        builder: (_) => _DetailScreen(axis: axis, row: row),
      );

  @override
  Widget build(BuildContext context) {
    // Kapsama düşükse sayı az sayıda kalemin sırtında duruyor demektir.
    final thin = row.lastCoverage < 0.25;

    return ScreenFrame(
      leading: Pressable(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(
            Glyph.back,
            size: 17,
            color: context.c.ink,
            stroke: 1.6,
          ),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: kGutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Lbl(
                  row.code == null ? axis.label : '${axis.label} · ${row.code}',
                ),
                const SizedBox(height: 4),
                Text(row.name, style: T.display),
                const SizedBox(height: 10),
                BigNumber(Fmt.dec1(row.changePct), size: 44),
                const SizedBox(height: 2),
                Text(
                  'Taban ay 100 kabul edilerek, ${row.series.length} aylık '
                  'seri boyunca toplam değişim.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: context.c.muted,
                  ),
                ),
                const SizedBox(height: 16),
                if (row.series.length >= 2)
                  LineChart(
                    height: 120,
                    series: [
                      ChartSeries(
                        values: row.levels,
                        color: context.c.ink,
                        endDot: true,
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Grafik için en az iki ay gerekiyor.',
                      style: TextStyle(fontSize: 11.5, color: context.c.muted),
                    ),
                  ),
                const SizedBox(height: 16),
                const Hairline(),
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 2),
                  child: Lbl('AY AY SEVİYE'),
                ),
                for (final p in row.series.reversed)
                  LedgerRow(
                    name: Fmt.monthLong(p.month),
                    sub: '${p.month.year}',
                    amount: Fmt.dec1(p.level),
                  ),
                const SizedBox(height: 14),
                if (thin)
                  Text(
                    'Bu seri, son ayda harcamanın küçük bir bölümünü '
                    'kapsıyor. Az sayıda kalemin fiyat hareketi burada '
                    'olduğundan büyük görünebilir.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: context.c.hot,
                    ),
                  )
                else
                  Text(
                    'Seviye, taban ayı 100 alan zincirlenmiş endekstir. '
                    'Genel endeksle aynı yöntem, yalnızca bu kümeye '
                    'kısıtlanmış ve ağırlıklar küme içinde yeniden '
                    'dağıtılmış hâli.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: context.c.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
