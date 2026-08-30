import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ocr.dart';
import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/glass.dart';
import '../widgets/icons.dart';
import '../widgets/screen_frame.dart';
import 'draft_receipt_screen.dart';

/// Fiş yakalama. Kamera ya da galeriden görüntü alır, cihaz üstünde okur ve
/// taslağa geçer.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  static Route<bool> route() => CupertinoPageRoute<bool>(
    fullscreenDialog: true,
    builder: (_) => const CaptureScreen(),
  );

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _ocr = const Ocr();
  final _picker = ImagePicker();
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        // Fiş uzun ve dar; yüksek çözünürlük OCR'ın küçük punto okumasına
        // yarıyor, sıkıştırmayı düşük tutuyoruz.
        imageQuality: 92,
        maxWidth: 2400,
      );
      if (file == null) {
        setState(() => _busy = false);
        return;
      }

      final parsed = await _ocr.readReceipt(file.path);
      if (!mounted) return;

      if (parsed.lines.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Fişte satır okunamadı. Işığı artırıp fişi düz tutarak tekrar dene.';
        });
        return;
      }

      final saved = await Navigator.of(context)
          .push(DraftReceiptScreen.route(parsed));
      if (!mounted) return;
      if (saved == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Görüntü okunamadı. Başka bir fotoğrafla dene.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Fiş ekle',
      trailing: Pressable(
        onTap: () => Navigator.of(context).pop(false),
        child: Padding(
          padding: EdgeInsets.all(4),
          child: LineIcon(
            Glyph.close,
            size: 17,
            color: context.c.muted,
            stroke: 1.6,
          ),
        ),
      ),
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              const SizedBox(height: 8),
              const Text('Fişi okut', style: T.display),
              const SizedBox(height: 10),
              Text(
                'Fişin fotoğrafı cihazdan çıkmaz. Metin cihaz üstünde okunur; '
                'sunucuya yalnızca eşleşmiş satırlar gider.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: context.c.muted,
                ),
              ),
              const SizedBox(height: 22),
              const _Guide(),
              const SizedBox(height: 22),
              PrimaryButton(
                label: _busy ? 'Okunuyor…' : 'Kamerayı aç',
                onTap: _busy ? null : () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Galeriden seç',
                dark: false,
                onTap: _busy ? null : () => _pick(ImageSource.gallery),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: context.c.hot,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Okumayı kolaylaştıran üç kısa kural.
class _Guide extends StatelessWidget {
  const _Guide();

  static const _tips = [
    'Fişi düz bir zemine koy, kırışıkları aç.',
    'Tamamı kadraja girsin — üstteki market adı ve alttaki toplam dahil.',
    'Gölge düşürme; termal kâğıt soluk basar.',
  ];

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Lbl('İYİ OKUMA İÇİN'),
        const SizedBox(height: 8),
        for (final tip in _tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 9),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.c.muted,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: context.c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
