-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

SET check_function_bodies = false;

CREATE SCHEMA private AUTHORIZATION postgres;

CREATE FUNCTION private.keep_newest_sync_row()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
begin
    if new.updated_at > now() + interval '10 minutes' then
        raise exception 'updated_at is too far in the future'
            using errcode = '22007';
    end if;
    if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
        return old;
    end if;
    return new;
end;
$function$;

REVOKE ALL ON FUNCTION private.keep_newest_sync_row() FROM PUBLIC;

CREATE TABLE public.bean_photos (
  id          uuid                     NOT NULL,
  created_at  timestamp with time zone DEFAULT now() NOT NULL,
  updated_at  timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at  timestamp with time zone,
  "order"     integer                  DEFAULT 0 NOT NULL,
  bean_id     uuid,
  remote_path text
);

ALTER TABLE public.bean_photos
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bean_photos
  ADD CONSTRAINT bean_photos_order_nonnegative CHECK ("order" >= 0);

ALTER TABLE public.bean_photos
  ADD CONSTRAINT bean_photos_pkey PRIMARY KEY (id);

GRANT INSERT, SELECT, UPDATE ON public.bean_photos TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.bean_photos TO service_role;

CREATE INDEX bean_photos_bean_id_idx ON public.bean_photos (bean_id);

CREATE TRIGGER bean_photos_keep_newest
  BEFORE INSERT OR UPDATE ON public.bean_photos
  FOR EACH ROW
  EXECUTE FUNCTION private.keep_newest_sync_row();

CREATE POLICY anon_insert_bean_photos ON public.bean_photos
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY anon_select_bean_photos ON public.bean_photos
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY anon_update_bean_photos ON public.bean_photos
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE TABLE public.beans (
  id                    uuid                     NOT NULL,
  created_at            timestamp with time zone DEFAULT now() NOT NULL,
  updated_at            timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at            timestamp with time zone,
  name                  text                     DEFAULT ''::text NOT NULL,
  roaster_name          text,
  country               text,
  region                text,
  farm                  text,
  varietal              text,
  process               text,
  roast_level           text,
  roast_date            timestamp with time zone,
  roaster_notes         text,
  my_flavor_tags        text[]                   DEFAULT '{}'::text[] NOT NULL,
  finished_at           timestamp with time zone,
  pending_next_pourover jsonb,
  pending_next_espresso jsonb
);

ALTER TABLE public.beans
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.beans
  ADD CONSTRAINT beans_my_flavor_tags_no_nulls CHECK (array_position(my_flavor_tags, NULL::text) IS NULL);

ALTER TABLE public.beans
  ADD CONSTRAINT beans_name_length CHECK (char_length(name) <= 500);

ALTER TABLE public.beans
  ADD CONSTRAINT beans_pending_next_espresso_object CHECK (pending_next_espresso IS NULL OR jsonb_typeof(pending_next_espresso) = 'object'::text);

ALTER TABLE public.beans
  ADD CONSTRAINT beans_pending_next_pourover_object CHECK (pending_next_pourover IS NULL OR jsonb_typeof(pending_next_pourover) = 'object'::text);

ALTER TABLE public.beans
  ADD CONSTRAINT beans_pkey PRIMARY KEY (id);

ALTER TABLE public.bean_photos
  ADD CONSTRAINT bean_photos_bean_id_fkey FOREIGN KEY (bean_id) REFERENCES public.beans(id) ON DELETE RESTRICT;

GRANT INSERT, SELECT, UPDATE ON public.beans TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.beans TO service_role;

CREATE TRIGGER beans_keep_newest
  BEFORE INSERT OR UPDATE ON public.beans
  FOR EACH ROW
  EXECUTE FUNCTION private.keep_newest_sync_row();

CREATE POLICY anon_insert_beans ON public.beans
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY anon_select_beans ON public.beans
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY anon_update_beans ON public.beans
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE TABLE public.brews (
  id                uuid                     NOT NULL,
  created_at        timestamp with time zone DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at        timestamp with time zone,
  brewed_at         timestamp with time zone DEFAULT now() NOT NULL,
  method_raw        text                     DEFAULT 'pourover'::text NOT NULL,
  brewers           text[]                   DEFAULT '{}'::text[] NOT NULL,
  recipe            jsonb                    DEFAULT '{"pours": []}'::jsonb NOT NULL,
  taste             jsonb                    DEFAULT '{"balance": {}, "negatives": [], "positives": []}'::jsonb NOT NULL,
  next_recipe_draft jsonb,
  photo_path        text,
  bean_id           uuid
);

ALTER TABLE public.brews
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.brews
  ADD CONSTRAINT brews_bean_id_fkey FOREIGN KEY (bean_id) REFERENCES public.beans(id) ON DELETE RESTRICT;

ALTER TABLE public.brews
  ADD CONSTRAINT brews_brewers_no_nulls CHECK (array_position(brewers, NULL::text) IS NULL);

ALTER TABLE public.brews
  ADD CONSTRAINT brews_method_raw_value CHECK (method_raw = ANY (ARRAY['pourover'::text, 'espresso'::text]));

ALTER TABLE public.brews
  ADD CONSTRAINT brews_next_recipe_draft_object CHECK (next_recipe_draft IS NULL OR jsonb_typeof(next_recipe_draft) = 'object'::text);

ALTER TABLE public.brews
  ADD CONSTRAINT brews_pkey PRIMARY KEY (id);

ALTER TABLE public.brews
  ADD CONSTRAINT brews_recipe_object CHECK (jsonb_typeof(recipe) = 'object'::text);

ALTER TABLE public.brews
  ADD CONSTRAINT brews_taste_object CHECK (jsonb_typeof(taste) = 'object'::text);

GRANT INSERT, SELECT, UPDATE ON public.brews TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.brews TO service_role;

CREATE INDEX brews_bean_id_idx ON public.brews (bean_id);

CREATE TRIGGER brews_keep_newest
  BEFORE INSERT OR UPDATE ON public.brews
  FOR EACH ROW
  EXECUTE FUNCTION private.keep_newest_sync_row();

CREATE POLICY anon_insert_brews ON public.brews
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY anon_select_brews ON public.brews
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY anon_update_brews ON public.brews
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE TABLE public.grinders (
  id         uuid                     NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  name       text                     DEFAULT ''::text NOT NULL,
  stepless   boolean                  DEFAULT false NOT NULL
);

ALTER TABLE public.grinders
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.grinders
  ADD CONSTRAINT grinders_name_length CHECK (char_length(name) <= 500);

ALTER TABLE public.grinders
  ADD CONSTRAINT grinders_pkey PRIMARY KEY (id);

GRANT INSERT, SELECT, UPDATE ON public.grinders TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.grinders TO service_role;

CREATE TRIGGER grinders_keep_newest
  BEFORE INSERT OR UPDATE ON public.grinders
  FOR EACH ROW
  EXECUTE FUNCTION private.keep_newest_sync_row();

CREATE POLICY anon_insert_grinders ON public.grinders
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY anon_select_grinders ON public.grinders
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY anon_update_grinders ON public.grinders
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE TABLE public.lexicon_terms (
  id         uuid                     NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  term       text                     DEFAULT ''::text NOT NULL,
  field_raw  text                     DEFAULT 'varietal'::text NOT NULL
);

ALTER TABLE public.lexicon_terms
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.lexicon_terms
  ADD CONSTRAINT lexicon_terms_field_raw_value
    CHECK
    (field_raw = ANY (ARRAY['name'::text, 'roaster'::text, 'country'::text, 'region'::text, 'farm'::text, 'varietal'::text, 'process'::text, 'roastLevel'::text,
    'tastingNote'::text]));

ALTER TABLE public.lexicon_terms
  ADD CONSTRAINT lexicon_terms_pkey PRIMARY KEY (id);

ALTER TABLE public.lexicon_terms
  ADD CONSTRAINT lexicon_terms_term_shape CHECK (char_length(term) <= 200 AND term = lower(term));

GRANT INSERT, SELECT, UPDATE ON public.lexicon_terms TO anon;

GRANT MAINTAIN, REFERENCES, TRIGGER, TRUNCATE ON public.lexicon_terms TO service_role;

CREATE TRIGGER lexicon_terms_keep_newest
  BEFORE INSERT OR UPDATE ON public.lexicon_terms
  FOR EACH ROW
  EXECUTE FUNCTION private.keep_newest_sync_row();

CREATE POLICY anon_insert_lexicon_terms ON public.lexicon_terms
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY anon_select_lexicon_terms ON public.lexicon_terms
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY anon_update_lexicon_terms ON public.lexicon_terms
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

-- `db diff` (pg-delta) only diffs DDL on objects it owns; it does not pick up DML (the bucket
-- row insert) or policies on the platform-managed storage.objects table, so those are appended
-- here by hand from schemas/dripwatch.sql. Keep this block in sync if that section changes.
insert into storage.buckets (id, name, public)
values
    ('bean-photos', 'bean-photos', false),
    ('brew-photos', 'brew-photos', false)
on conflict (id) do update
    set name = excluded.name,
        public = false;

grant select, insert, update on table storage.objects to anon;

drop policy if exists anon_select_bean_photo_objects on storage.objects;
create policy anon_select_bean_photo_objects on storage.objects
    for select to anon
    using (bucket_id = 'bean-photos');
drop policy if exists anon_insert_bean_photo_objects on storage.objects;
create policy anon_insert_bean_photo_objects on storage.objects
    for insert to anon
    with check (bucket_id = 'bean-photos');
drop policy if exists anon_update_bean_photo_objects on storage.objects;
create policy anon_update_bean_photo_objects on storage.objects
    for update to anon
    using (bucket_id = 'bean-photos')
    with check (bucket_id = 'bean-photos');

drop policy if exists anon_select_brew_photo_objects on storage.objects;
create policy anon_select_brew_photo_objects on storage.objects
    for select to anon
    using (bucket_id = 'brew-photos');
drop policy if exists anon_insert_brew_photo_objects on storage.objects;
create policy anon_insert_brew_photo_objects on storage.objects
    for insert to anon
    with check (bucket_id = 'brew-photos');
drop policy if exists anon_update_brew_photo_objects on storage.objects;
create policy anon_update_brew_photo_objects on storage.objects
    for update to anon
    using (bucket_id = 'brew-photos')
    with check (bucket_id = 'brew-photos');