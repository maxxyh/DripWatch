-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

ALTER TABLE public.beans
  ADD COLUMN price_sgd double precision;

ALTER TABLE public.beans
  ADD CONSTRAINT beans_price_sgd_positive CHECK (price_sgd IS NULL OR price_sgd > 0::double precision);

ALTER TABLE public.beans
  ADD COLUMN bag_size_grams double precision;

ALTER TABLE public.beans
  ADD CONSTRAINT beans_bag_size_grams_positive CHECK (bag_size_grams IS NULL OR bag_size_grams > 0::double precision);
