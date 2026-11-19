-- Test (review follow-up round 2, item 6): at most 10 comments per user per
-- 10 minutes. The 11th is refused with error code 54000.
-- now() is fixed for the whole test transaction, so "10 minutes later" is
-- simulated by backdating created_at as the database owner (superuser).
begin;
select plan(7);

-- ---------- Fixtures ----------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('22222222-2222-2222-2222-222222222222', 'bob@students.utech.edu.jm');

insert into public.portfolios (id, user_id, slug, title, status, visibility) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'open-work-a1b2c3d4e5', 'Open work', 'active', 'public');

-- ---------- Alice comments as herself ----------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok(
  $$ do $d$ begin
       for i in 1..10 loop
         insert into public.comments (portfolio_id, user_id, content)
         values ('aaaaaaaa-0000-0000-0000-000000000001',
                 '11111111-1111-1111-1111-111111111111', 'Comment ' || i);
       end loop;
     end $d$ $$,
  '10 comments within 10 minutes are accepted');

select throws_ok(
  $$ insert into public.comments (portfolio_id, user_id, content)
     values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Eleventh') $$,
  '54000', 'Too many comments. Please wait a few minutes.',
  'the 11th comment is refused with 54000');

-- Another user is not affected by Alice's limit.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.comments (portfolio_id, user_id, content)
     values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Bob here') $$,
  'another user can still comment');

-- Hidden comments still count (Alice cannot see them through RLS, but the
-- trigger is security definer and counts them anyway).
reset role;
update public.comments set hidden = true where user_id = '11111111-1111-1111-1111-111111111111';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is(
  (select count(*) from public.comments where user_id = '11111111-1111-1111-1111-111111111111'),
  0::bigint, 'Alice cannot see her hidden comments');

select throws_ok(
  $$ insert into public.comments (portfolio_id, user_id, content)
     values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Still too soon') $$,
  '54000', null,
  'hidden comments still count towards the limit');

-- 11 minutes later: the earlier comments fall outside the window.
reset role;
update public.comments set created_at = now() - interval '11 minutes'
 where user_id = '11111111-1111-1111-1111-111111111111';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok(
  $$ insert into public.comments (portfolio_id, user_id, content)
     values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Later') $$,
  'after 10 minutes a new comment is accepted');

-- The trigger function cannot be called directly by app users.
select ok(
  not has_function_privilege('authenticated', 'public.enforce_comment_rate_limit()', 'execute'),
  'app users cannot execute the rate-limit function');

select * from finish();
rollback;
