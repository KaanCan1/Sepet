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

import { isBulk, sizeStated, sizesIn } from '../src/size-hint.js';

describe('Fişte boy yazıyor mu', () => {
  it('yazan boyu yakalıyor', () => {
    expect(sizeStated('SUT TAM YAGLI 1L', 'litre', 1)).toBe(true);
    expect(sizeStated('AYRAN 500ML', 'litre', 0.5)).toBe(true);
    expect(sizeStated('BEYAZ PEYNIR 600G', 'kilogram', 0.6)).toBe(true);
    expect(sizeStated('YUMURTA 30LU', 'adet', 30)).toBe(true);
    // Kanonik birim adet ama etiket ağırlık; etiketin kendisi aranıyor.
    expect(sizeStated('PROTEIN BAR 50 G', 'adet', 1, '50 g')).toBe(true);
  });

  it('yazmayan boyu uydurmuyor', () => {
    // Bu ekranın varlık sebebi: fiş gramajı basmıyor, sorulmak zorunda.
    expect(sizeStated('MIGROS T.YAGLI YOGU.', 'kilogram', 1)).toBe(false);
    expect(sizeStated('PINAR BEYAZ PEYNIR', 'kilogram', 0.6)).toBe(false);
    expect(sizeStated('MIGROS EKSTRA CECIL', 'kilogram', 0.2)).toBe(false);
  });

  it('başka bir boyu bu boy sanmıyor', () => {
    expect(sizeStated('SUT TAM YAGLI 1L', 'litre', 0.5)).toBe(false);
    expect(sizeStated('YUMURTA 30LU', 'adet', 15)).toBe(false);
  });

  it('birimi grubun kanonik birimine çeviriyor', () => {
    expect(sizesIn('BEYAZ PEYNIR 600G', 'kilogram')).toEqual([0.6]);
    expect(sizesIn('AYRAN 500ML', 'litre')).toEqual([0.5]);
  });
});

describe('Kasada tartılan kalemler', () => {
  it('birim adı boy etiketiyse paket yok demektir', () => {
    expect(isBulk('kilogram')).toBe(true);
    expect(isBulk('litre')).toBe(true);
    expect(isBulk('600 g')).toBe(false);
    expect(isBulk("30'lu")).toBe(false);
  });
});
