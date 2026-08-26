import { Router } from 'express';
import { requireAuth, type AuthedRequest } from '../auth.js';
import { query } from '../db.js';

export const accountRouter = Router();
accountRouter.use(requireAuth);

/// Hesabı ve ona bağlı her şeyi siler.
///
/// Profil ekranındaki "Hesabı sil" düğmesi bunu ÇAĞIRMIYORDU: yalnızca
/// oturumu kapatıyordu, oysa ekranda "tüm fişlerin ve endeks geçmişin
/// kalıcı olarak silinir" yazıyordu. Veri sunucuda olduğu gibi kalıyordu —
/// hem yalan bir arayüz hem de KVKK'nın silme hakkının karşılanmaması.
///
/// Yabancı anahtarlar basamaklı: kullanıcıyı silmek kimlik kayıtlarını,
/// fişleri, satırları, gözlemleri ve türetilmiş endeksi de götürüyor.
accountRouter.delete('/', async (req: AuthedRequest, res) => {
  await query(`DELETE FROM users WHERE id = $1`, [req.userId]);
  res.json({ ok: true });
});

/// Jetonun hâlâ geçerli olup olmadığını söyleyen ucuz uç.
///
/// Doğrulamanın kendisi `requireAuth`'ta oluyor: buraya girildiyse jeton
/// çözülmüş ve hesap duruyor demek. Uygulama açılışta bunu çağırıyor —
/// eskiden `/index` çağırıyordu ve endeks SQL'i tam olarak "oturum hâlâ
/// açık mı" sorusunu cevaplamak için çalışıyordu.
accountRouter.get('/me', async (req: AuthedRequest, res) => {
  const rows = await query<{ email: string | null }>(
    `SELECT email FROM users WHERE id = $1`,
    [req.userId],
  );
  res.json({ userId: req.userId, email: rows[0]?.email ?? null });
});
