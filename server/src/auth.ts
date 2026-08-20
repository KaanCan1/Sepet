import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
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
export function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
): void {
  const header = req.header('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    res.status(401).json({ error: 'Oturum gerekli' });
    return;
  }
  try {
    const payload = jwt.verify(token, env.jwtSecret) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: 'Oturum geçersiz ya da süresi dolmuş' });
  }
}
