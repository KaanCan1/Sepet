import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'atoms.dart';
import 'glass.dart';
import 'icons.dart';

/// "eşleşme?" sorusu — buzlu cam alt sayfa.
///
/// Katalogda arama yapıyor; seçilen ürün hem satırı düzeltiyor hem de bu
/// market + ham metin için alias'a yazılıyor, böylece aynı fiş formatı bir
/// daha sorulmuyor.
class MatchSheet extends StatefulWidget {
  const MatchSheet({super.key, required this.line});

  final ReceiptLine line;

  /// Seçilen kanonik ürünün kimliğini döndürür.
  static Future<String?> show(BuildContext context, ReceiptLine line) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0x00000000),
        barrierColor: const Color(0x3316181A),
        builder: (_) => MatchSheet(line: line),
      );

  @override
  State<MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<MatchSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: _initialQuery,
  );
  List<ProductRef> _results = const [];
  bool _loading = true;
  String? _error;
  bool _started = false;

  /// Ham metnin ilk kelimesi genelde ürünün kendisi: "AYCICEK YAGI 5L".
  String get _initialQuery => widget.line.raw.split(RegExp(r'\s+')).first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // initState'te InheritedWidget'a bakılamıyor; ilk arama buradan.
    if (_started) return;
    _started = true;
    _search(_initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = AppScope.repoOf(context);
    try {
      final rows = await repo.searchCatalog(q);
      if (mounted) setState(() => _results = rows);
    } on ApiException catch (e) {
      // Arama başarısızsa "sonuç yok" demek yanlış olur — ikisi ayrı durum.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final pad = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: GlassBar(
        borderSide: GlassEdge.none,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + pad + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Lbl('FİŞTEKİ SATIR'),
              const SizedBox(height: 5),
              Text(widget.line.rawLine, style: T.num12),
              const SizedBox(height: 16),
              const Lbl('HANGİ ÜRÜN?'),
              const SizedBox(height: 8),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: TextField(
                  controller: _controller,
                  autofocus: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Katalogda ara',
                    hintStyle: TextStyle(fontSize: 13.5, color: C.muted),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  style: const TextStyle(fontSize: 13.5, color: C.ink),
                  onChanged: _search,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: _loading && _results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: C.muted,
                            ),
                          ),
                        ),
                      )
                    : _error != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 12, color: C.hot),
                        ),
                      )
                    : _results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Katalogda eşleşen ürün yok. Farklı bir kelime dene.',
                          style: TextStyle(fontSize: 12, color: C.muted),
                        ),
                      )
                    : PaperCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const Hairline(),
                          itemBuilder: (context, i) {
                            final p = _results[i];
                            return Pressable(
                              scale: .99,
                              onTap: () => Navigator.of(context).pop(p.id),
                              child: Container(
                                color: C.card,
                                padding: const EdgeInsets.fromLTRB(
                                  13,
                                  13,
                                  13,
                                  13,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.title,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: C.ink,
                                        ),
                                      ),
                                    ),
                                    const LineIcon(
                                      Glyph.chevron,
                                      size: 13,
                                      color: C.muted,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Seçimin bu markete ait fiş formatı için kaydedilir.',
                style: TextStyle(fontSize: 11, color: C.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
