import 'package:flutter/cupertino.dart';

import '../theme/tokens.dart';
import '../widgets/atoms.dart';
import '../widgets/screen_frame.dart';

/// Aydınlatma metni (KVKK m. 10). Bilgilendirmedir — onay kutusu YOKTUR.
/// Kurul'un 18.02.2026 tarihli 2026/347 ilke kararı aydınlatma ile açık
/// rızanın tek metinde birleştirilmesini yasaklıyor; açık rıza ayrı ekranda.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static Route<void> route() => CupertinoPageRoute(
    fullscreenDialog: true,
    builder: (_) => const PrivacyScreen(),
  );

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      showTopBar: false,
      slivers: [
        SliverPadding(
          padding: kGutter,
          sliver: SliverList.list(
            children: [
              // Üst barda "Aydınlatma metni", altında "Verilerin nereye
              // gidiyor" yazıyordu. İkincisi metnin ne anlattığını söylüyor;
              // birincisi belgenin resmî adı ve o zaten profildeki satırda
              // yazıyor.
              LargeTitle(
                'Verilerin\nnereye gidiyor',
                onClose: () => Navigator.of(context).pop(),
              ),
              const _Section(
                'VERİ SORUMLUSU',
                'Sepet uygulamasını geliştiren gerçek kişi. İletişim: '
                    'uygulama içindeki destek adresi.',
              ),
              const _Section(
                'İŞLENEN VERİLER',
                'Kimlik ve iletişim: e-posta adresin.\n'
                    'İşlem güvenliği: oturum kaydı, cihaz türü.\n'
                    'Alışveriş kaydı: fişten okunan ürün adı, tutar, tarih, '
                    'market adı ve şehir.',
              ),
              const _Section(
                'FİŞİN FOTOĞRAFI',
                'Sunucuya gönderilmez. Metin cihaz üstünde okunur (ML Kit / '
                    'Vision), görsel işlem biter bitmez silinir. Sunucuya '
                    'yalnızca eşleşmiş satırlar gider.',
              ),
              const _Section(
                'İŞLEME AMACI VE HUKUKİ SEBEBİ',
                'Hesabını kurmak, fişlerini saklamak ve kişisel enflasyon '
                    'endeksini hesaplamak. Hukuki sebep: sözleşmenin ifası '
                    '(KVKK m. 5/2-c). Bu işleme için açık rıza aranmaz, çünkü '
                    'hizmetin kendisi budur.',
              ),
              const _Section(
                'AÇIK RIZAYA BAĞLI OLANLAR',
                'Toplulaştırılmış anonim endekse katkı ve pazarlama iletileri '
                    'yalnızca açık rıza verirsen işlenir. İkisi de isteğe '
                    'bağlıdır; vermezsen uygulama aynen çalışır. Rızanı '
                    'istediğin an Profil > İzinler ekranından geri alabilirsin.',
              ),
              const _Section(
                'ÖZEL NİTELİKLİ VERİ',
                'Toplanmıyor. Fişte sağlıkla ilgili bir ürün geçse bile '
                    'kanonik eşleme sağlık verisi üretmez; ilaç ve reçete '
                    'satırları endekse dahil edilmez.',
              ),
              const _Section(
                'AKTARIM',
                'Veriler Türkiye içindeki sunucularda tutulur. Yurt dışına '
                    'aktarım yapılması hâlinde KVKK m. 9 kapsamında standart '
                    'sözleşme imzalanır ve Kurum\'a bildirilir.',
              ),
              const _Section(
                'SAKLAMA SÜRESİ',
                'Hesabını silene kadar. Silme talebinden sonra 30 gün içinde '
                    'tüm fiş kayıtları kalıcı olarak yok edilir.',
              ),
              const _Section(
                'HAKLARIN (KVKK m. 11)',
                'Verilerine erişme, düzeltme, silme, aktarılan üçüncü kişileri '
                    'öğrenme ve işlemeye itiraz etme haklarına sahipsin. '
                    'Fişleri dışa aktarma seçeneği Profil ekranında.',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Lbl(title),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(fontSize: 12, height: 1.6, color: context.c.ink),
        ),
      ],
    ),
  );
}
