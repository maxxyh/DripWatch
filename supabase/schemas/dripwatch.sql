-- DripWatch declarative schema.
--
-- UUIDs are client-generated to match SwiftData's UUID() defaults. The database
-- therefore does not manufacture primary keys, and updated_at remains a
-- client-owned Syncable field. A trigger prevents an older client timestamp
-- from replacing a newer server row; the next pull returns the winning row.
-- Swift Data blobs (Bean.bagPhoto, BeanPhoto.data, and Brew.photo) are kept out
-- of Postgres and belong in the private Storage buckets declared below.
--
-- PROTOTYPE EXPOSURE: this first sync shape has no auth or ownership column.
-- The anon policies intentionally expose one shared notebook to unauthenticated
-- clients for prototyping. Replace them with authenticated ownership policies
-- before using this schema for multiple users or sensitive data.

create table if not exists public.beans (
    id uuid primary key,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    name text not null default ''
        constraint beans_name_length check (char_length(name) <= 500),
    roaster_name text,
    country text,
    region text,
    farm text,
    varietal text,
    process text,
    roast_level text,
    roast_date timestamptz,
    roaster_notes text,
    price_sgd double precision
        constraint beans_price_sgd_positive check (price_sgd is null or price_sgd > 0),
    bag_size_grams double precision
        constraint beans_bag_size_grams_positive check (bag_size_grams is null or bag_size_grams > 0),
    my_flavor_tags text[] not null default '{}'::text[]
        constraint beans_my_flavor_tags_no_nulls
        check (array_position(my_flavor_tags, null::text) is null),
    finished_at timestamptz,
    pending_next_pourover jsonb
        constraint beans_pending_next_pourover_object
        check (pending_next_pourover is null or jsonb_typeof(pending_next_pourover) = 'object'),
    pending_next_espresso jsonb
        constraint beans_pending_next_espresso_object
        check (pending_next_espresso is null or jsonb_typeof(pending_next_espresso) = 'object')
);

create table if not exists public.grinders (
    id uuid primary key,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    name text not null default ''
        constraint grinders_name_length check (char_length(name) <= 500),
    stepless boolean not null default false
);

create table if not exists public.lexicon_terms (
    id uuid primary key,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    term text not null default ''
        constraint lexicon_terms_term_shape
        check (char_length(term) <= 200 and term = lower(term)),
    field_raw text not null default 'varietal'
        constraint lexicon_terms_field_raw_value
        check (field_raw in (
            'name', 'roaster', 'country', 'region', 'farm', 'varietal',
            'process', 'roastLevel', 'tastingNote'
        ))
);

create table if not exists public.bean_photos (
    id uuid primary key,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    "order" integer not null default 0
        constraint bean_photos_order_nonnegative check ("order" >= 0),
    bean_id uuid
        constraint bean_photos_bean_id_fkey
        references public.beans(id) on delete restrict,
    remote_path text
);

create table if not exists public.brews (
    id uuid primary key,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    brewed_at timestamptz not null default now(),
    method_raw text not null default 'pourover'
        constraint brews_method_raw_value
        check (method_raw in ('pourover', 'espresso')),
    brewers text[] not null default '{}'::text[]
        constraint brews_brewers_no_nulls
        check (array_position(brewers, null::text) is null),
    recipe jsonb not null default '{"pours": []}'::jsonb
        constraint brews_recipe_object
        check (jsonb_typeof(recipe) = 'object'),
    taste jsonb not null default '{"positives": [], "negatives": [], "balance": {}}'::jsonb
        constraint brews_taste_object
        check (jsonb_typeof(taste) = 'object'),
    next_recipe_draft jsonb
        constraint brews_next_recipe_draft_object
        check (next_recipe_draft is null or jsonb_typeof(next_recipe_draft) = 'object'),
    photo_path text,
    bean_id uuid
        constraint brews_bean_id_fkey
        references public.beans(id) on delete restrict
);

create index if not exists bean_photos_bean_id_idx on public.bean_photos(bean_id);
create index if not exists brews_bean_id_idx on public.brews(bean_id);

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.keep_newest_sync_row()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
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
$$;

revoke all on function private.keep_newest_sync_row() from public, anon, authenticated;

drop trigger if exists beans_keep_newest on public.beans;
create trigger beans_keep_newest before insert or update on public.beans
    for each row execute function private.keep_newest_sync_row();
drop trigger if exists brews_keep_newest on public.brews;
create trigger brews_keep_newest before insert or update on public.brews
    for each row execute function private.keep_newest_sync_row();
drop trigger if exists bean_photos_keep_newest on public.bean_photos;
create trigger bean_photos_keep_newest before insert or update on public.bean_photos
    for each row execute function private.keep_newest_sync_row();
drop trigger if exists grinders_keep_newest on public.grinders;
create trigger grinders_keep_newest before insert or update on public.grinders
    for each row execute function private.keep_newest_sync_row();
drop trigger if exists lexicon_terms_keep_newest on public.lexicon_terms;
create trigger lexicon_terms_keep_newest before insert or update on public.lexicon_terms
    for each row execute function private.keep_newest_sync_row();

-- The app uses soft deletion. No anon or authenticated role receives DELETE.
grant usage on schema public to anon;
revoke all on table public.beans, public.brews, public.bean_photos,
    public.grinders, public.lexicon_terms from anon, authenticated;
grant select, insert, update on table public.beans, public.brews,
    public.bean_photos, public.grinders, public.lexicon_terms to anon;

alter table public.beans enable row level security;
alter table public.brews enable row level security;
alter table public.bean_photos enable row level security;
alter table public.grinders enable row level security;
alter table public.lexicon_terms enable row level security;

-- The three policies per table are deliberately separate so the prototype's
-- grant surface is explicit and can later be replaced operation by operation.
drop policy if exists anon_select_beans on public.beans;
create policy anon_select_beans on public.beans
    for select to anon
    using (true);
drop policy if exists anon_insert_beans on public.beans;
create policy anon_insert_beans on public.beans
    for insert to anon
    with check (true);
drop policy if exists anon_update_beans on public.beans;
create policy anon_update_beans on public.beans
    for update to anon
    using (true)
    with check (true);

drop policy if exists anon_select_brews on public.brews;
create policy anon_select_brews on public.brews
    for select to anon
    using (true);
drop policy if exists anon_insert_brews on public.brews;
create policy anon_insert_brews on public.brews
    for insert to anon
    with check (true);
drop policy if exists anon_update_brews on public.brews;
create policy anon_update_brews on public.brews
    for update to anon
    using (true)
    with check (true);

drop policy if exists anon_select_bean_photos on public.bean_photos;
create policy anon_select_bean_photos on public.bean_photos
    for select to anon
    using (true);
drop policy if exists anon_insert_bean_photos on public.bean_photos;
create policy anon_insert_bean_photos on public.bean_photos
    for insert to anon
    with check (true);
drop policy if exists anon_update_bean_photos on public.bean_photos;
create policy anon_update_bean_photos on public.bean_photos
    for update to anon
    using (true)
    with check (true);

drop policy if exists anon_select_grinders on public.grinders;
create policy anon_select_grinders on public.grinders
    for select to anon
    using (true);
drop policy if exists anon_insert_grinders on public.grinders;
create policy anon_insert_grinders on public.grinders
    for insert to anon
    with check (true);
drop policy if exists anon_update_grinders on public.grinders;
create policy anon_update_grinders on public.grinders
    for update to anon
    using (true)
    with check (true);

drop policy if exists anon_select_lexicon_terms on public.lexicon_terms;
create policy anon_select_lexicon_terms on public.lexicon_terms
    for select to anon
    using (true);
drop policy if exists anon_insert_lexicon_terms on public.lexicon_terms;
create policy anon_insert_lexicon_terms on public.lexicon_terms
    for insert to anon
    with check (true);
drop policy if exists anon_update_lexicon_terms on public.lexicon_terms;
create policy anon_update_lexicon_terms on public.lexicon_terms
    for update to anon
    using (true)
    with check (true);

-- Keep both image buckets private. Access is granted only by the bucket-scoped
-- storage.objects policies below; no service key or other secret belongs here.
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
