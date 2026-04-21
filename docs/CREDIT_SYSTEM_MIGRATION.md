# Balance -> Credit System Migration Plan

Bu doküman, **balance** yaklaşımını tamamen kaldırıp **credit** yaklaşımına güvenli şekilde geçiş için planı ve SQL uygulama notlarını içerir.

## Hedef
- `balance` kavramını kod/veritabanı/API yüzeyinden kaldırmak.
- Kullanımı `credits` üzerinden takip etmek.
- Geriye dönük balance verisini güvenli ve tekrar çalıştırılabilir (idempotent) biçimde taşımak.

## Veri Modeli (Hedef)
- `users.credits BIGINT NOT NULL DEFAULT 0`
- `users_credits_non_negative CHECK (credits >= 0)`
- `credit_ledger`:
  - `user_id`
  - `delta`
  - `reason`
  - `reference_id`
  - `created_at`

## Kritik Geçiş Kuralları
1. **Idempotent backfill:** Migration tekrar çalışsa bile backfill çift kayıt üretmemeli.
2. **Veri güvenliği:** `credits` negatif olamaz.
3. **Kolon-varlık kontrolü:** `users.balance` mevcut değilse backfill adımı atlanmalı.
4. **Geridönüşümlü adım:** Önce yeni yapı eklenir/backfill yapılır, en sonda `balance` kaldırılır.
5. **Kesme anı (cutover):** Uygulama okumaları/yazmaları `credits` üzerine alınmadan eski kolon silinmemeli.

## SQL Uygulaması
`sql/001_credit_system.sql` aşağıdakileri yapar:
- `schema_migrations_meta` ile tek seferlik backfill işaretlemesi kullanır.
- `credit_ledger` üzerinde backfill kayıtları için unique index tanımlar.
- `users.balance` kolonu varsa `users.credits` backfill uygular (yalnızca `credits` hâlâ 0 iken).
- `balance_transactions` tablosunu ve `users.balance` kolonunu güvenli biçimde kaldırır (`IF EXISTS`).

## Operasyon Sırası
1. Deploy (dual-read/dual-write destekli sürüm)
2. Migration çalıştır
3. Doğrulama sorguları çalıştır
4. Uygulamayı `credits`-only moda al

## Doğrulama Sorguları (Örnek)
```sql
-- 1) Negatif kredi var mı?
SELECT COUNT(*) AS negative_credit_rows
FROM users
WHERE credits < 0;

-- 2) Backfill ledger tekrar üretildi mi?
SELECT user_id, COUNT(*)
FROM credit_ledger
WHERE reason = 'migration_backfill' AND reference_id = 'users.balance'
GROUP BY user_id
HAVING COUNT(*) > 1;

-- 3) Eski kolon tamamen kalktı mı?
SELECT COUNT(*) AS balance_column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name = 'balance';
```
