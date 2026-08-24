-- Up Migration

-- Endeks dışı satırlar.
--
-- Fişte ürün olmayan ama tutarı olan kalemler var: kasa poşeti, depozito,
-- taşıma bedeli. Bunlar bir şey satın alındığını gösterir ama kişisel
-- enflasyon sepetinin parçası değil — poşetin fiyatı yoğurdun fiyatıyla
-- aynı sepette taşınmaz.
--
-- Şimdiye kadar bunlar `pending` kalıyordu: endekse girmiyorlardı (trigger
-- yalnızca 'auto' ve 'confirmed' satırları alıyor) ama kullanıcıya
-- "bu ne?" diye sorulmaya devam ediyordu ve hiçbir zaman doğru cevabı
-- olmayan bir soruydu.
--
-- `rejected` bu iş için kullanılabilirdi ama anlamı farklı: onu kullanıcı
-- verir. `excluded` sistemin kararı, kullanıcının değil — ekranda da
-- ayrı görünmesi gerekiyor.
ALTER TYPE match_status ADD VALUE IF NOT EXISTS 'excluded';

-- Down Migration
-- PostgreSQL enum değeri silmeyi desteklemiyor. Geri alma, değeri kullanan
-- satırları `pending`e çekmekle sınırlı; tip olduğu gibi kalıyor.
UPDATE receipt_lines SET status = 'pending' WHERE status = 'excluded';
