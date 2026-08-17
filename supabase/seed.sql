-- Local dev seed data, run by `supabase start` / `supabase db reset` after migrations.
--
-- A small, representative slice of the real shared notebook (3 beans, 8 brews, 4 grinders,
-- pulled via the Supabase MCP against the hosted project on 2026-08-17) rather than a full
-- dump: keeps this file readable, keeps `supabase start` fast, and avoids permanently baking
-- the whole personal notebook into git history. Covers a pourover bean with a pending plan
-- (Los Rodriguez), an espresso bean with a pending plan (Fazenda Estrela Carvalho), and a
-- finished bean with no plan (Sidamo ALO Atote) — enough to exercise Shelf's fresh/finished
-- split, PlanCard, RecipeEditor, RecipeReadout, and brew-diff annotations.
--
-- Bean and brew photos reference real (downsized, already-app-processed) images from the same
-- three beans, seeded into Storage separately from ./seed/bean-photos and ./seed/brew-photos
-- via [storage.buckets.*] in config.toml — `supabase start` / `db reset` apply both together.
-- Paths must be exactly `<owning-row-id>/<sha256-of-bytes>.jpg`: the photos API route
-- (src/app/api/photos/[bucket]/[...path]/route.ts) enforces that canonical format and 404s
-- anything else, so the id folder + hash filename below aren't just tidiness, they're required.

insert into public.grinders (id, name, stepless) values
    ('d74e7d3e-14e1-418f-ba9d-bbec0fc5d290', '1Zpresso Q2', false),
    ('ba737de2-c235-41ee-9b6d-cd3a1bc02cf0', '1Zpresso ZP6', false),
    ('b96005d8-b587-4bc1-acba-5541a1b204ba', 'Df54', true),
    ('d2d8decf-6826-405a-aae0-8af6cd5746b2', '1Zpresso J', false);

insert into public.beans (
    id, name, roaster_name, country, region, farm, varietal, process, roast_level,
    roast_date, roaster_notes, my_flavor_tags, finished_at,
    pending_next_pourover, pending_next_espresso
) values
    (
        '36e8b781-1cb1-4ff8-af97-fbeaea17f60d', 'Los Rodriguez', 'Maxi', 'Bolivia', 'Caranavi',
        'THE Rodriguez Family', 'Caturra', 'Washed', 'Light', '2026-07-31 05:43:00+00',
        'RED Apple, Nectarine, Red Tea', '{}', null,
        '{"pours":[{"id":"E6CA1308-015A-47C1-A4DB-3D979D6D51F4","order":1,"toGrams":60},{"id":"E4D246E4-1B51-4EBD-AC7C-576BC55F909F","order":2,"toGrams":145},{"id":"7A4D177A-36A5-4992-ADD4-251B758AA11F","order":3,"toGrams":235},{"id":"02204DAB-0B08-4C48-8E8B-13281BB6EA6B","order":4,"toGrams":320}],"ratio":16,"doseGrams":20,"pourCount":4,"grindMajor":5,"waterTempC":92,"grinderName":"1Zpresso ZP6","bloomTimeSec":40,"grindClickOffset":0}'::jsonb,
        null
    ),
    (
        '91463777-74bb-4c07-a76b-e9f668b1ccce', 'Fazenda Estrela Carvalho', 'Maxi', 'Brazil',
        'Minas Gerais', 'JOSE Ricardo DE Carvalho', 'Yellow Bourbon', 'Natural', 'Medium-Dark',
        '2026-07-30 05:31:00+00', 'DARK Cherry, Raisin, Chocolate', '{}', null,
        null,
        '{"pours":[],"doseGrams":19,"grindMajor":15,"yieldGrams":36,"grinderName":"Df54","surfWaitSec":10,"steamModeSec":5,"preInfusionSec":6,"grindClickOffset":0}'::jsonb
    ),
    (
        '477ee2f8-622b-4ac1-a1be-4aaad3390cef', 'Sidamo ALO Atote', 'Yelei Lab', 'Ethiopia',
        'Sidamo', 'ALO Atote', 'Mini 74158', 'Natural', 'Light', '2026-07-10 05:23:00+00',
        'Orange Juice, Grape, Peach', '{}', '2026-08-14 05:40:17.782+00',
        null, null
    );

insert into public.brews (id, bean_id, brewed_at, method_raw, recipe, taste, photo_path) values
    (
        '0fa563fd-821b-4830-b1db-3029d049e186', '36e8b781-1cb1-4ff8-af97-fbeaea17f60d',
        '2026-08-07 05:44:08.828+00', 'pourover',
        '{"pours":[{"id":"E6CA1308-015A-47C1-A4DB-3D979D6D51F4","order":1,"toGrams":60},{"id":"E4D246E4-1B51-4EBD-AC7C-576BC55F909F","order":2,"toGrams":180},{"id":"7A4D177A-36A5-4992-ADD4-251B758AA11F","order":3,"toGrams":300}],"ratio":15,"doseGrams":20,"pourCount":3,"grindMajor":3,"waterTempC":92,"grinderName":"1Zpresso J","bloomTimeSec":30,"grindClickOffset":0}'::jsonb,
        '{"note":"I want it more thin","balance":{},"negatives":[],"positives":["Bright","Juicy","Red"]}'::jsonb,
        null
    ),
    (
        'b9e0fde8-37b3-4e71-8b9b-33bf09d23b42', '36e8b781-1cb1-4ff8-af97-fbeaea17f60d',
        '2026-08-12 05:40:06.954+00', 'pourover',
        '{"pours":[{"id":"E6CA1308-015A-47C1-A4DB-3D979D6D51F4","order":1,"toGrams":60},{"id":"E4D246E4-1B51-4EBD-AC7C-576BC55F909F","order":2,"toGrams":190},{"id":"7A4D177A-36A5-4992-ADD4-251B758AA11F","order":3,"toGrams":320}],"ratio":16,"doseGrams":20,"pourCount":3,"grindMajor":3,"waterTempC":90,"grinderName":"1Zpresso J","bloomTimeSec":30,"grindClickOffset":0,"totalDrawdownSec":138}'::jsonb,
        '{"balance":{},"negatives":["Burnt???","No Listed Flavours Is It Underextracted?"],"positives":[]}'::jsonb,
        null
    ),
    (
        '8d6fe603-c10b-4fdb-bfc5-3002ba400a3b', '36e8b781-1cb1-4ff8-af97-fbeaea17f60d',
        '2026-08-17 05:26:58.19+00', 'pourover',
        '{"pours":[{"id":"E6CA1308-015A-47C1-A4DB-3D979D6D51F4","order":1,"toGrams":60},{"id":"E4D246E4-1B51-4EBD-AC7C-576BC55F909F","order":2,"toGrams":145},{"id":"7A4D177A-36A5-4992-ADD4-251B758AA11F","order":3,"toGrams":235},{"id":"02204DAB-0B08-4C48-8E8B-13281BB6EA6B","order":4,"toGrams":320}],"ratio":16,"doseGrams":20,"pourCount":4,"grindMajor":5,"waterTempC":92,"grinderName":"1Zpresso ZP6","bloomTimeSec":40,"grindClickOffset":0,"totalDrawdownSec":150}'::jsonb,
        '{"balance":{},"negatives":["Bitter","Should Try Longer TDD?"],"positives":[]}'::jsonb,
        null
    ),
    (
        'f57ecbf4-963a-4f2a-842e-579b8afc5c3d', '91463777-74bb-4c07-a76b-e9f668b1ccce',
        '2026-08-16 01:51:08+00', 'espresso',
        '{"pours":[],"doseGrams":19,"grindMajor":16,"yieldGrams":36,"grinderName":"Df54","shotTimeSec":22,"surfWaitSec":10,"steamModeSec":5,"preInfusionSec":6,"grindClickOffset":0}'::jsonb,
        '{"balance":{},"negatives":["Can Be Thicker."],"positives":[]}'::jsonb,
        null
    ),
    (
        '5c800347-1f4c-48ef-b25e-c898478fc4dd', '91463777-74bb-4c07-a76b-e9f668b1ccce',
        '2026-08-17 01:56:31.552+00', 'espresso',
        '{"pours":[],"doseGrams":19,"grindMajor":15,"yieldGrams":34,"grinderName":"Df54","shotTimeSec":45,"surfWaitSec":10,"steamModeSec":5,"preInfusionSec":6,"grindClickOffset":0}'::jsonb,
        '{"rating":4,"balance":{},"negatives":["Can Be Sweeter Maybe Pull Longer?"],"positives":["Less Sour","More Balanced","Nutty","Cereal In Milk?","When Cool, Raisin Appeared"]}'::jsonb,
        '5c800347-1f4c-48ef-b25e-c898478fc4dd/d9c90ba155cc6acc66e48f814cec41cd6ad2781848b3759fa7a39094d71002dd.jpg'
    ),
    (
        '5c107545-e331-4def-8f5c-fdf575fb165a', '477ee2f8-622b-4ac1-a1be-4aaad3390cef',
        '2026-07-30 05:25:22.606+00', 'pourover',
        '{"pours":[{"id":"B81BD7FF-0A32-456F-84ED-B1B33E8651FA","order":1,"toGrams":45},{"id":"2434790A-E230-4C12-8391-3E7BAD490A78","order":2,"toGrams":150},{"id":"EA016A21-7103-4B0A-8030-41B015EA1E41","order":3,"toGrams":225}],"ratio":15,"doseGrams":15,"pourCount":3,"grindMajor":3,"waterTempC":94,"grinderName":"1Zpresso J","bloomTimeSec":40,"grindClickOffset":1}'::jsonb,
        '{"balance":{},"negatives":[],"positives":["Orange! Yum"]}'::jsonb,
        null
    ),
    (
        '254f9d8f-e247-4472-8586-7ab44aca3b5b', '477ee2f8-622b-4ac1-a1be-4aaad3390cef',
        '2026-08-11 05:31:34.1+00', 'pourover',
        '{"pours":[{"id":"B81BD7FF-0A32-456F-84ED-B1B33E8651FA","order":1,"toGrams":45},{"id":"2434790A-E230-4C12-8391-3E7BAD490A78","order":2,"toGrams":150},{"id":"EA016A21-7103-4B0A-8030-41B015EA1E41","order":3,"toGrams":225}],"ratio":15,"doseGrams":15,"pourCount":3,"grindMajor":5,"waterTempC":92,"grinderName":"1Zpresso ZP6","bloomTimeSec":40,"grindClickOffset":0}'::jsonb,
        '{"balance":{},"negatives":[],"positives":["Orange But Weaker"]}'::jsonb,
        null
    ),
    (
        '29ad3e30-866c-4d75-ad61-97bf1e27f6f1', '477ee2f8-622b-4ac1-a1be-4aaad3390cef',
        '2026-08-14 05:27:57.376+00', 'pourover',
        '{"pours":[{"id":"B81BD7FF-0A32-456F-84ED-B1B33E8651FA","order":1,"toGrams":50},{"id":"2434790A-E230-4C12-8391-3E7BAD490A78","order":2,"toGrams":145},{"id":"EA016A21-7103-4B0A-8030-41B015EA1E41","order":3,"toGrams":238.5}],"ratio":15,"doseGrams":15.9,"pourCount":3,"grindMajor":5,"waterTempC":94,"grinderName":"1Zpresso ZP6","bloomTimeSec":40,"grindClickOffset":0,"totalDrawdownSec":165}'::jsonb,
        '{"rating":5,"balance":{"body":2,"acidity":5,"sweetness":4,"bitterness":1},"negatives":[],"positives":["Distinct Orange On Bright End"]}'::jsonb,
        '29ad3e30-866c-4d75-ad61-97bf1e27f6f1/7b2b91a2c5f61a3b704ea4e597e42c729dfeecab337a9ba82e0f0ec1e60a43cb.jpg'
    );

insert into public.bean_photos (id, bean_id, "order", remote_path) values
    ('e8ca1557-c41b-4c05-9725-d2066d63aad5', '36e8b781-1cb1-4ff8-af97-fbeaea17f60d', 0, 'e8ca1557-c41b-4c05-9725-d2066d63aad5/bdc903ebd00c28043cedb47b397c04e997ab3d9de92cf1fc4fbee20b9907ab2b.jpg'),
    ('d2db2a3c-1e8c-4e68-ba64-b70eba5a6c7d', '91463777-74bb-4c07-a76b-e9f668b1ccce', 0, 'd2db2a3c-1e8c-4e68-ba64-b70eba5a6c7d/b6006100e688f1b525b9657b6367f3f26091585e85a10a26b202270c2ff6929b.jpg'),
    ('e332276c-7b98-43d5-acc7-99987fca0aee', '477ee2f8-622b-4ac1-a1be-4aaad3390cef', 0, 'e332276c-7b98-43d5-acc7-99987fca0aee/b866cfec41a9715f4b9b5555c64114199cc1f75947d0ca8e3d5d920381e4deb4.jpg');
