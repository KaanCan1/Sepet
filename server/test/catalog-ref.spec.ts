import { describe, expect, it } from 'vitest';
import { canonicalId } from './fixtures/catalog-ref.js';

/**
 * Bu testler yardımcının kendisini değil, testlerin katalog hakkındaki
 * varsayımını koruyor. Katalog büyüdükçe "nasılsa tek satır gelir"
 * varsayımı üç kez kırıldı; kimliğin üç parçalı olması artık zorunlu.
 */
describe('Katalog referansı', () => {
  it('grup, marka ve boy verilince tek kalem buluyor', async () => {
    const id = await canonicalId('Süt, tam yağlı', 'Sütaş', '1 litre');
    expect(id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('markasız kalemi marka verilmeden buluyor', async () => {
    const id = await canonicalId('Yumurta', null, "30'lu");
    expect(id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('aynı grup + boy farklı markalarda karışmıyor', async () => {
    const pinar = await canonicalId('Beyaz peynir', 'Pınar', '600 g');
    const sutas = await canonicalId('Beyaz peynir', 'Sütaş', '600 g');
    expect(pinar).not.toBe(sutas);
  });

  it('bulunamayınca gruptaki kalemleri hata mesajında yazıyor', async () => {
    // Testi düzeltecek kişinin ihtiyacı olan bilgi tam olarak bu.
    await expect(
      canonicalId('Beyaz peynir', 'Pınar', '750 g'),
    ).rejects.toThrow(/Gruptaki kalemler:.*Pınar 600 g/s);
  });
});
