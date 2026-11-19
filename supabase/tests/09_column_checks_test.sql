-- Test (review follow-up):
--   5. profiles.avatar_key must be null or start with the profile's own id + '/'.
--   6. portfolios.slug must end with '-' plus 10 random lowercase letters/digits.
-- Constraint violations use error code 23514 (check_violation).
begin;
select plan(13);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('22222222-2222-2222-2222-222222222222', 'bob@students.utech.edu.jm');

-- Act as Alice, editing her own profile and creating portfolios.
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

-- ---------- avatar_key ----------
select lives_ok(
  $$ update public.profiles set avatar_key = '11111111-1111-1111-1111-111111111111/avatar.webp'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  'avatar in the user''s own folder is accepted');

select lives_ok(
  $$ update public.profiles set avatar_key = null
     where id = '11111111-1111-1111-1111-111111111111' $$,
  'no avatar (null) is accepted');

select throws_ok(
  $$ update public.profiles set avatar_key = '22222222-2222-2222-2222-222222222222/avatar.webp'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'avatar pointing into someone else''s folder is rejected');

select throws_ok(
  $$ update public.profiles set avatar_key = 'avatar.webp'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'avatar outside any user folder is rejected');

select throws_ok(
  $$ update public.profiles set avatar_key = '11111111-1111-1111-1111-111111111111'
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '23514', null,
  'avatar key that is only the id (no "/") is rejected');

-- ---------- slug ----------
select lives_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'night-market-short-k3x9q2m7ab', 'Night market') $$,
  'title words + 10-character random suffix is accepted');

select lives_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'portfolio-0a1b2c3d4e', 'Untitled') $$,
  'a single word + suffix is accepted');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'night-market', 'No suffix') $$,
  '23514', null,
  'a slug without a random suffix is rejected');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'night-market-k3x9q2m', 'Short suffix') $$,
  '23514', null,
  'a suffix shorter than 10 characters is rejected');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'k3x9q2m7ab', 'Suffix only') $$,
  '23514', null,
  'a suffix with no title part is rejected');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'Night-Market-K3X9Q2M7AB', 'Upper case') $$,
  '23514', null,
  'upper-case letters are rejected');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'night--market-k3x9q2m7ab', 'Double dash') $$,
  '23514', null,
  'double hyphens are rejected');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111',
             repeat('a', 70) || '-k3x9q2m7ab', 'Too long') $$,
  '23514', null,
  'a slug longer than 80 characters is rejected');

select * from finish();
rollback;
