-- Up Migration

-- Üçüncü durum: TANINDI AMA ENDEKSE GİRMİYOR.
--
-- Bugüne kadar bir satır ya eşleşiyordu ya "eşleşme bekliyor" kalıyordu.
-- Havuz (#92) bu ikiliği yetersiz bıraktı: zincirlerin sattığı 876 kalemin
-- 622'sinin sepette karşılığı YOK ve olmaması da doğru — sepet ağırlıklı ve
-- sabit bir TÜFE sepeti, elli bin kalemle şişirilemez.
--
-- O 622 kalemden birini alan kullanıcı bugün "eşleşme bekliyor" görüyor ve o
-- satır sonsuza kadar orada kalıyor: sorulan sorunun cevabı katalogda yok.
-- Kullanıcı için bu "uygulama benim fişimi anlamıyor" demek — oysa uygulama
-- ürünü gayet iyi tanıyor.
--
-- off_basket bunu söylüyor: "Ülker Çikolatalı Gofret 36 g — biliyorum, ama
-- endeksine katmıyorum." Sorulmuyor, çünkü sorulacak bir şey yok.
--
-- excluded'dan farkı: excluded "bu bir ürün DEĞİL" (kasa poşeti, indirim
-- satırı). off_basket "bu bir ürün ama benim sepetimde değil". İkisini aynı
-- kutuya koymak, kullanıcıya kâğıt poşetle çikolatayı aynı şey gibi
-- göstermek olurdu.
ALTER TYPE match_status ADD VALUE IF NOT EXISTS 'off_basket';

-- Down Migration

-- PostgreSQL enum değeri kaldırmayı desteklemiyor; tipi yeniden kurmak
-- gerekiyordu ve bu, satırları taşımak demek. Geri alma bu yüzden yalnızca
-- durumu boşaltıyor: off_basket satırlar yeniden sorulur hâle dönüyor.
UPDATE receipt_lines SET status = 'pending' WHERE status = 'off_basket';
