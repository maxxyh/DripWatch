-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

ALTER TABLE public.beans
  DROP CONSTRAINT beans_price_sgd_positive;

ALTER TABLE public.beans
  ALTER COLUMN price_sgd TYPE numeric(12,2) USING price_sgd::numeric(12,2);

ALTER TABLE public.beans
  ADD CONSTRAINT beans_price_sgd_positive CHECK (price_sgd IS NULL OR price_sgd > 0::numeric);
