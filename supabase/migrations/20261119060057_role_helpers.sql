-- =============================================================================
-- Role helpers: is_moderator() and is_admin()
-- =============================================================================
-- Used inside RLS policies and moderation functions to ask "is the current
-- signed-in user a moderator / an admin?". The answer comes from profiles.role
-- (this replaces the demo's admin_roles table).
--
-- Why "security definer": the function reads profiles with the rights of its owner,
-- so it works no matter what the profiles policies say, and a policy on profiles
-- can call it without looping back into itself.
--
-- Why "set search_path = ''": a security definer function must not look up
-- names in schemas a caller could change. Every name below is schema-qualified.
--
-- Both return false (never null) for anonymous visitors.
-- =============================================================================

-- True for moderators AND admins (admins can do everything a moderator can).
create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role in ('moderator', 'admin')
  );
$$;

-- True only for admins.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

-- Only signed-in users need these. Anonymous policies never call them.
revoke execute on function public.is_moderator() from public, anon;
revoke execute on function public.is_admin()     from public, anon;
grant  execute on function public.is_moderator() to authenticated;
grant  execute on function public.is_admin()     to authenticated;
