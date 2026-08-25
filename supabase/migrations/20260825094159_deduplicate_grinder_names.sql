-- Preserve a stepless classification recorded on either spelling before retiring duplicates.
with duplicate_groups as (
    select lower(btrim(name)) as identity_key,
           (array_agg(id order by created_at, id))[1] as keeper_id,
           bool_or(stepless) as stepless
    from public.grinders
    where deleted_at is null and btrim(name) <> ''
    group by lower(btrim(name))
    having count(*) > 1
)
update public.grinders as grinder
set stepless = duplicate_groups.stepless,
    updated_at = greatest(now(), grinder.updated_at + interval '1 microsecond')
from duplicate_groups
where grinder.id = duplicate_groups.keeper_id
  and grinder.stepless is distinct from duplicate_groups.stepless;

-- Soft-delete every duplicate except the oldest stable row; recipes keep their display spelling.
with ranked as (
    select id,
           row_number() over (
               partition by lower(btrim(name))
               order by created_at, id
           ) as identity_rank
    from public.grinders
    where deleted_at is null and btrim(name) <> ''
)
update public.grinders as grinder
set deleted_at = greatest(now(), grinder.updated_at + interval '1 microsecond'),
    updated_at = greatest(now(), grinder.updated_at + interval '1 microsecond')
from ranked
where grinder.id = ranked.id and ranked.identity_rank > 1;

create unique index grinders_active_name_unique
    on public.grinders (lower(btrim(name)))
    where deleted_at is null and btrim(name) <> '';
