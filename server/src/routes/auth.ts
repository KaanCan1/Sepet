import { Router } from 'express';
import { signToken } from '../auth.js';
import { env } from '../env.js';
import { one, query } from '../db.js';

export const authRouter = Router();

/**
 * Sağlayıcısız geliştirme girişi.
 *
 * Gerçek akış Apple Developer üyeliği ve Google istemci kimlikleri alınınca
 * `/auth/apple` ve `/auth/google` olarak gelecek: sağlayıcının kimlik
 * token'ı doğrulanacak, `auth_identities`'e yazılacak ve aynı `signToken`
 * çağrılacak. Bu ucun ürettiği token'la onlarınki aynı biçimde.
 */
authRouter.post('/dev-login', async (req, res) => {
  if (!env.devLoginEnabled) {
    res.status(404).json({ error: 'Bulunamadı' });
    return;
  }
  const email = String(req.body?.email ?? '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(email)) {
    res.status(400).json({ error: 'Geçerli bir e-posta adresi gerekli' });
    return;
  }

  const existing = await query<{ id: string }>(
    `SELECT id FROM users WHERE lower(email) = $1 AND deleted_at IS NULL`,
    [email],
  );
  const user =
    existing[0] ??
    (await one<{ id: string }>(
      `INSERT INTO users (email) VALUES ($1) RETURNING id`,
      [email],
    ));

  await query(
    `INSERT INTO auth_identities (user_id, provider, provider_user_id, email_at_provider)
     VALUES ($1, 'email', $2, $2)
     ON CONFLICT (provider, provider_user_id) DO NOTHING`,
    [user.id, email],
  );

  res.json({ token: signToken(user.id), userId: user.id });
});
