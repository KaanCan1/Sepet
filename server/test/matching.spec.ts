import { describe, expect, it } from 'vitest';
import { isNonIndexLine } from '../src/non-index.js';

describe('Endeks dışı satırlar', () => {
  it('kasa poşetini eliyor', () => {
    expect(isNonIndexLine('MIGROS PLASTIK POSET')).toBe(true);
    expect(isNonIndexLine('POŞET')).toBe(true);
    expect(isNonIndexLine('TASIMA POSETI')).toBe(true);
    expect(isNonIndexLine('DEPOZITO')).toBe(true);
  });

  it('gerçek ürünlere dokunmuyor', () => {
    // Liste dar tutuldu: şüpheliyi sessizce elemek, sormaktan kötü.
    expect(isNonIndexLine('MIGROS T.YAGLI YOGU.')).toBe(false);
    expect(isNonIndexLine('PILIÇ BONFİLE')).toBe(false);
    expect(isNonIndexLine('HASATA PILAVLIK B')).toBe(false);
    expect(isNonIndexLine('POSETLI CAY')).toBe(false);
  });
});
