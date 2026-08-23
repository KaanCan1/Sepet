import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { query } from './db.js';
import { env } from './env.js';

export interface AuthedRequest extends Request {
  userId?: string;
}

export function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, env.jwtSecret, { expiresIn: '30d' });
}

/**
 * Bearer token'ı çözer. Gerçek Apple/Google akışı geldiğinde değişen tek yer
 * token'ı ÜRETEN uç olacak; doğrulayan bu katman aynı kalır.
 */
export async function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.header('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'Oturum gerekli' });
    return;
  }
  let userId: string;
  try {
    userId = (jwt.verify(token, env.jwtSecret) as { sub: string }).sub;
  } catch {
    res.status(401).json({ error: 'Oturum geçersiz ya da süresi dolmuş' });
    return;
  }

  // Jeton durumsuz ve 30 gün geçerli; hesap silindiğinde geçersizleşmesinin
  // başka yolu yok. Bu kontrol olmadan silinmiş bir hesabın jetonu aylarca
  // kabul edilmeye devam ediyordu. Birincil anahtar üzerinden tek arama.
  const rows = await query(`SELECT 1 FROM users WHERE id = $1`, [userId]);
  if (rows.length === 0) {
    res.status(401).json({ error: 'Oturum geçersiz ya da süresi dolmuş' });
    return;
  }

  req.userId = userId;
  next();
}
