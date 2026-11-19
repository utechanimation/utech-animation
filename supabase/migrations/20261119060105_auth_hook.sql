-- =============================================================================
-- Sign-up rules
-- =============================================================================
--   1. hook_before_user_created(event): the Supabase "Before User Created" auth
--      hook (brief 6.1). Only @students.utech.edu.jm emails, or an email with an
--      unused staff invite, may create an account. Everyone else gets a 403.
--   2. handle_new_user(): creates the profiles row when a user is created, and
--      gives invited staff the role from their invite.
--
-- !! MANUAL STEP on the hosted project: enable the hook in the Supabase dashboard
-- !! under Authentication -> Hooks -> "Before User Created", choosing the Postgres
-- !! function public.hook_before_user_created. A migration cannot switch it on.
-- !! (For the local database it is switched on in supabase/config.toml.)
--
-- Linking a personal Google/Microsoft account to an existing user (graduates)
-- does not create a new user, so this hook does not block it.
--
-- Checked against the Supabase docs (Nov 2026): the event carries the email at
-- event->'user'->>'email'; return '{}' to allow, or {"error": {"http_code",
-- "message"}} to reject. The docs advise NOT using "security definer" for hooks,
-- and instead granting the auth role (supabase_auth_admin) exactly what it needs.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Before User Created hook
-- -----------------------------------------------------------------------------
create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_email text := lower(event->'user'->>'email');
begin
  -- UTech students
  if v_email like '%@students.utech.edu.jm' then
    return '{}'::jsonb;
  end if;

  -- Lecturers and other staff an admin has invited (each invite works once)
  if exists (select 1 from public.staff_invites
             where email = v_email and used_at is null) then
    return '{}'::jsonb;
  end if;

  -- Everyone else
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'Please sign in with your UTech student Microsoft account.'));
end;
$$;

-- Only the auth system may run the hook.
grant execute on function public.hook_before_user_created(jsonb) to supabase_auth_admin;
revoke execute on function public.hook_before_user_created(jsonb) from public, anon, authenticated;

-- The auth role has no rights in the public schema by default. Give it just
-- enough to read staff_invites, and an RLS policy so it can see the rows.
grant usage on schema public to supabase_auth_admin;
grant select on public.staff_invites to supabase_auth_admin;

-- The auth system may read staff invites, so the sign-up hook can check them.
create policy "Auth system reads staff invites"
  on public.staff_invites for select
  to supabase_auth_admin
  using (true);


-- -----------------------------------------------------------------------------
-- 2. Create a profile for every new user
-- -----------------------------------------------------------------------------
-- Runs inside the same transaction that inserts into auth.users. The username
-- is left empty; the student picks it on first sign-in (a later task).
-- If the email has an unused staff invite, the profile gets that role and the
-- invite is marked used, so it cannot be used a second time.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(new.email);
  v_role  text := 'student';
begin
  update public.staff_invites
     set used_at = now()
   where email = v_email and used_at is null
  returning role into v_role;

  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    -- Microsoft and Google send the display name in one of these fields
    left(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), 120),
    coalesce(v_role, 'student')
  );

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
