-- =============================================================================
-- Row Level Security: who may read and write what
-- =============================================================================
-- Source of truth: brief section 5, "Key RLS rules".
--
-- Two layers protect each table:
--   1. GRANTS say which COLUMNS a role may touch at all. Supabase normally grants
--      everything to "anon" (visitors) and "authenticated" (signed-in users), so
--      we revoke that first and grant back only what is needed. This is how
--      students are stopped from writing status, review_state, role,
--      storage_used, hidden, or any moderation table: they have no grant.
--   2. POLICIES say which ROWS a role may see or change.
--
-- Moderators read everything, but every state change (approve, reject, warn,
-- take down, appeals, reports) goes through the functions in
-- *_moderation_functions.sql, which check the role and write audit_log.
--
-- Server code that uses the service-role key bypasses RLS. It is used only on the
-- server (uploads, storage_used, deleting files) and never in the browser.
--
-- Notes:
--   * "(select auth.uid())" is wrapped in a select so Postgres runs it once per
--     query instead of once per row (Supabase performance advice).
--   * Policies "to anon" never call is_moderator()/is_admin(), because visitors
--     are not allowed to run those functions.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Helper: is this portfolio approved and shown to others (public OR unlisted)?
-- Used when liking or commenting. It is security definer because unlisted
-- portfolios are not readable through the portfolios policies.
-- It returns only true/false, so it reveals nothing about the portfolio.
-- -----------------------------------------------------------------------------
create or replace function public.portfolio_is_open(p_portfolio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.portfolios
    where id = p_portfolio_id
      and status = 'active'
      and visibility in ('public', 'unlisted')
  );
$$;

revoke execute on function public.portfolio_is_open(uuid) from public, anon;
grant  execute on function public.portfolio_is_open(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- Helper: may the current user change this portfolio's tags and credits?
-- Yes only if they own it AND it is in a normal state ('pending_review',
-- 'active' or 'rejected'), not while it is taken down or under appeal.
-- The same status list is used by the owner policies on portfolios below.
-- -----------------------------------------------------------------------------
create or replace function public.owner_can_edit_portfolio(p_portfolio_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.portfolios
    where id = p_portfolio_id
      and user_id = (select auth.uid())
      and status in ('pending_review', 'active', 'rejected')
  );
$$;

revoke execute on function public.owner_can_edit_portfolio(uuid) from public, anon;
grant  execute on function public.owner_can_edit_portfolio(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- Start from zero: take away Supabase's default "everything" grants.
-- -----------------------------------------------------------------------------
revoke all on table
  public.profiles, public.staff_invites, public.portfolios, public.portfolio_items,
  public.tags, public.portfolio_tags, public.portfolio_credits, public.likes,
  public.comments, public.reports, public.warnings, public.takedowns, public.audit_log
from anon, authenticated;


-- =============================================================================
-- profiles
-- =============================================================================
-- Public profile fields only. storage_used is NOT granted: the server reads it
-- with the service role when checking the upload quota.
grant select (id, username, full_name, bio, avatar_key, year_of_study, role, status, created_at)
  on public.profiles to anon, authenticated;

-- A user may edit their own name, username, bio, avatar and year.
-- NOT role, status or storage_used (no grant).
grant update (username, full_name, bio, avatar_key, year_of_study)
  on public.profiles to authenticated;

-- No insert grant: the profile row is created by a trigger on sign-up (*_auth_hook.sql).
-- No delete grant: "Delete my account" runs on the server (it also deletes files).

-- Anyone, signed in or not, may read public profile fields of every profile
-- (profile pages are public; private columns are hidden by the grants above).
create policy "Profiles are readable by everyone"
  on public.profiles for select
  to anon, authenticated
  using (true);

-- A signed-in user may update only their own profile row.
create policy "Users update their own profile"
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));


-- =============================================================================
-- staff_invites (only admins; the sign-up hook also reads it)
-- =============================================================================
grant select, insert, update, delete on public.staff_invites to authenticated;

-- Only admins may see, add, change or remove lecturer invites.
create policy "Admins read staff invites"
  on public.staff_invites for select
  to authenticated
  using ((select public.is_admin()));

create policy "Admins add staff invites"
  on public.staff_invites for insert
  to authenticated
  with check ((select public.is_admin()));

create policy "Admins change staff invites"
  on public.staff_invites for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "Admins remove staff invites"
  on public.staff_invites for delete
  to authenticated
  using ((select public.is_admin()));

-- The auth system (role supabase_auth_admin) reads invites when deciding whether
-- a non-student email may sign up. See *_auth_hook.sql for its grants.


-- =============================================================================
-- portfolios
-- =============================================================================
-- Visitors get every column EXCEPT the moderation details reviewed_by,
-- has_pending_media and rejection_reason. Signed-in users get all columns
-- (owners need rejection_reason); the row policies below still apply.
-- Because of this, app code must list columns, not use select('*') (see RUNBOOK).
grant select (id, user_id, slug, title, description, cover_item_id, visibility, status,
              reviewed_at, upload_year, created_at, updated_at)
  on public.portfolios to anon;
grant select on public.portfolios to authenticated;

-- Students create portfolios. They cannot choose status, review fields or the
-- cover (cover changes are media changes and go through review).
grant insert (user_id, slug, title, description, visibility, upload_year)
  on public.portfolios to authenticated;

-- Text edits go live at once (brief 4.3). Only these columns may change.
grant update (title, description, visibility) on public.portfolios to authenticated;

grant delete on public.portfolios to authenticated;

-- Visitors see only approved, public portfolios. Unlisted portfolios are NOT
-- listed here; they are fetched by exact slug through get_portfolio_by_slug() below.
create policy "Visitors read active public portfolios"
  on public.portfolios for select
  to anon
  using (status = 'active' and visibility = 'public');

-- Signed-in users see active public portfolios, plus all of their own
-- (pending, rejected, private ...). Moderators see everything.
create policy "Users read public, own, or (moderators) all portfolios"
  on public.portfolios for select
  to authenticated
  using (
    (status = 'active' and visibility = 'public')
    or user_id = (select auth.uid())
    or (select public.is_moderator())
  );

-- OWNER WRITES are allowed only while the portfolio is in a normal state:
-- 'pending_review', 'active' or 'rejected'. While it is taken down, under
-- appeal, or locked after a denied appeal, the owner cannot edit or delete it,
-- so the work a moderator judged cannot be swapped or erased.
-- The same list is in owner_can_edit_portfolio() above (used by the tag and
-- credit policies). Change both together.

-- A user may create a portfolio only for themselves. The status column is not
-- granted, so every new portfolio starts as 'pending_review' (the column default).
create policy "Users create their own portfolios"
  on public.portfolios for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and status in ('pending_review', 'active', 'rejected')
  );

-- Owners may edit their own portfolio's text (columns limited by the grant above).
create policy "Owners update their own portfolios"
  on public.portfolios for update
  to authenticated
  using (
    user_id = (select auth.uid())
    and status in ('pending_review', 'active', 'rejected')
  )
  with check (
    user_id = (select auth.uid())
    and status in ('pending_review', 'active', 'rejected')
  );

-- Owners may delete their own portfolio. (Stored files are removed by server code.)
create policy "Owners delete their own portfolios"
  on public.portfolios for delete
  to authenticated
  using (
    user_id = (select auth.uid())
    and status in ('pending_review', 'active', 'rejected')
  );


-- =============================================================================
-- portfolio_items
-- =============================================================================
grant select on public.portfolio_items to anon, authenticated;

-- Owners may only reorder items. New items are created by server code after the
-- upload is checked (brief 4.4), so there is no insert/delete grant for users.
grant update (position) on public.portfolio_items to authenticated;

-- Visitors see only live items of active, public portfolios.
create policy "Visitors read live items of public portfolios"
  on public.portfolio_items for select
  to anon
  using (
    review_state = 'live'
    and exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.status = 'active' and p.visibility = 'public'
    )
  );

-- Signed-in users: the same, plus every item of their own portfolios
-- (including pending ones). Moderators see everything.
create policy "Users read live public items, own items, or (moderators) all"
  on public.portfolio_items for select
  to authenticated
  using (
    (review_state = 'live' and exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.status = 'active' and p.visibility = 'public'
    ))
    or exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.user_id = (select auth.uid())
    )
    or (select public.is_moderator())
  );

-- Owners may change the order (position) of items in their own portfolios.
create policy "Owners reorder their own items"
  on public.portfolio_items for update
  to authenticated
  using (exists (
    select 1 from public.portfolios p
    where p.id = portfolio_id and p.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.portfolios p
    where p.id = portfolio_id and p.user_id = (select auth.uid())
  ));


-- =============================================================================
-- tags (fixed list; only admins change it)
-- =============================================================================
grant select on public.tags to anon, authenticated;
grant insert, update, delete on public.tags to authenticated;

-- Everyone may read the tag list (it fills the dropdown and the Explore filter).
create policy "Tags are readable by everyone"
  on public.tags for select
  to anon, authenticated
  using (true);

-- Only admins may add, rename or remove tags (brief 4.5).
create policy "Admins add tags"
  on public.tags for insert
  to authenticated
  with check ((select public.is_admin()));

create policy "Admins rename tags"
  on public.tags for update
  to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "Admins remove tags"
  on public.tags for delete
  to authenticated
  using ((select public.is_admin()));


-- =============================================================================
-- portfolio_tags (which tags a portfolio uses; max 3 is a trigger)
-- =============================================================================
grant select on public.portfolio_tags to anon, authenticated;
grant insert, delete on public.portfolio_tags to authenticated;

-- Tag links are readable when the portfolio itself is readable by the caller
-- (the subquery on portfolios runs with the caller's own portfolio policies).
create policy "Tag links follow portfolio visibility"
  on public.portfolio_tags for select
  to anon, authenticated
  using (exists (select 1 from public.portfolios p where p.id = portfolio_id));

-- Owners add and remove tags on their own portfolios (a text edit, goes live at
-- once), but not while the portfolio is taken down or under appeal.
create policy "Owners add tags to their own portfolios"
  on public.portfolio_tags for insert
  to authenticated
  with check (public.owner_can_edit_portfolio(portfolio_id));

create policy "Owners remove tags from their own portfolios"
  on public.portfolio_tags for delete
  to authenticated
  using (public.owner_can_edit_portfolio(portfolio_id));


-- =============================================================================
-- portfolio_credits (collaborators)
-- =============================================================================
grant select on public.portfolio_credits to anon, authenticated;
-- Owners add credits and change the role text. status is not granted: a trigger
-- sets it on insert, and accepting/declining comes in a later task (Phase 3).
grant insert (portfolio_id, profile_id, external_name, role) on public.portfolio_credits to authenticated;
grant update (role) on public.portfolio_credits to authenticated;
grant delete on public.portfolio_credits to authenticated;

-- Visitors see accepted credits on active public portfolios.
create policy "Visitors read accepted credits of public portfolios"
  on public.portfolio_credits for select
  to anon
  using (
    status = 'accepted'
    and exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.status = 'active' and p.visibility = 'public'
    )
  );

-- Signed-in users: accepted credits on portfolios they can see, credits that
-- name them (so they can see their invites), all credits on their own
-- portfolios, and (moderators) everything.
create policy "Users read accepted, own, or (moderators) all credits"
  on public.portfolio_credits for select
  to authenticated
  using (
    (status = 'accepted' and exists (select 1 from public.portfolios p where p.id = portfolio_id))
    or profile_id = (select auth.uid())
    or exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.user_id = (select auth.uid())
    )
    or (select public.is_moderator())
  );

-- Owners add, edit and remove credits on their own portfolios, but not while
-- the portfolio is taken down or under appeal.
create policy "Owners add credits to their own portfolios"
  on public.portfolio_credits for insert
  to authenticated
  with check (public.owner_can_edit_portfolio(portfolio_id));

create policy "Owners edit credits on their own portfolios"
  on public.portfolio_credits for update
  to authenticated
  using (public.owner_can_edit_portfolio(portfolio_id))
  with check (public.owner_can_edit_portfolio(portfolio_id));

create policy "Owners remove credits from their own portfolios"
  on public.portfolio_credits for delete
  to authenticated
  using (public.owner_can_edit_portfolio(portfolio_id));


-- =============================================================================
-- likes
-- =============================================================================
grant select on public.likes to anon, authenticated;
grant insert (user_id, portfolio_id), delete on public.likes to authenticated;

-- Like counts are public for portfolios the caller can see.
create policy "Likes follow portfolio visibility"
  on public.likes for select
  to anon, authenticated
  using (exists (select 1 from public.portfolios p where p.id = portfolio_id));

-- Signed-in users like as themselves, only on active public or unlisted portfolios.
create policy "Users like active portfolios as themselves"
  on public.likes for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and public.portfolio_is_open(portfolio_id)
  );

-- Users remove only their own like.
create policy "Users remove their own likes"
  on public.likes for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- =============================================================================
-- comments
-- =============================================================================
grant select on public.comments to anon, authenticated;
-- hidden is NOT granted: only the auto-hide trigger and moderator functions set it.
grant insert (portfolio_id, user_id, content), delete on public.comments to authenticated;

-- Visitors see comments that are not hidden, on portfolios they can see.
create policy "Visitors read visible comments"
  on public.comments for select
  to anon
  using (
    not hidden
    and exists (select 1 from public.portfolios p where p.id = portfolio_id)
  );

-- Signed-in users: the same; moderators also see hidden comments to review them.
create policy "Users read visible comments, moderators read all"
  on public.comments for select
  to authenticated
  using (
    (not hidden and exists (select 1 from public.portfolios p where p.id = portfolio_id))
    or (select public.is_moderator())
  );

-- Signed-in users comment as themselves, only on active public or unlisted portfolios.
create policy "Users comment on active portfolios as themselves"
  on public.comments for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and public.portfolio_is_open(portfolio_id)
  );

-- Authors may delete their own comments. (Moderators delete through delete_comment().)
create policy "Authors delete their own comments"
  on public.comments for delete
  to authenticated
  using (user_id = (select auth.uid()));


-- =============================================================================
-- reports
-- =============================================================================
-- status is NOT granted: it starts as 'pending' and only resolve_report() changes it.
grant select on public.reports to authenticated;
grant insert (reporter_id, portfolio_id, comment_id, category, details) on public.reports to authenticated;

-- Reporters see their own reports; moderators see all reports.
create policy "Reporters read own reports, moderators read all"
  on public.reports for select
  to authenticated
  using (
    reporter_id = (select auth.uid())
    or (select public.is_moderator())
  );

-- Signed-in users file reports as themselves.
create policy "Users file reports as themselves"
  on public.reports for insert
  to authenticated
  with check (reporter_id = (select auth.uid()));


-- =============================================================================
-- warnings and takedowns (read-only here; changed only by moderation functions)
-- =============================================================================
grant select on public.warnings, public.takedowns to authenticated;

-- The portfolio owner sees warnings on their own work; moderators see all.
create policy "Owners and moderators read warnings"
  on public.warnings for select
  to authenticated
  using (
    exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.user_id = (select auth.uid())
    )
    or (select public.is_moderator())
  );

-- The portfolio owner sees takedowns of their own work; moderators see all.
create policy "Owners and moderators read takedowns"
  on public.takedowns for select
  to authenticated
  using (
    exists (
      select 1 from public.portfolios p
      where p.id = portfolio_id and p.user_id = (select auth.uid())
    )
    or (select public.is_moderator())
  );


-- =============================================================================
-- audit_log (read-only for moderators; written only by moderation functions)
-- =============================================================================
grant select on public.audit_log to authenticated;

create policy "Moderators read the audit log"
  on public.audit_log for select
  to authenticated
  using ((select public.is_moderator()));


-- =============================================================================
-- get_portfolio_by_slug(slug): the one way to open an UNLISTED portfolio
-- =============================================================================
-- Unlisted means "anyone with the link". RLS cannot tell "opened by exact link"
-- from "listed everything", so unlisted portfolios are left out of the policies
-- above, and this function returns ONE active public-or-unlisted portfolio by its
-- exact slug, together with what its page shows: live items, tags, accepted
-- credits, like count and visible comments.
--
-- Returns null when there is no such portfolio (pending, rejected, private,
-- taken down, or a wrong slug). Owners and moderators read their own / all
-- portfolios through the normal tables instead.
-- =============================================================================
create or replace function public.get_portfolio_by_slug(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'portfolio', jsonb_build_object(
      'id', p.id, 'slug', p.slug, 'title', p.title, 'description', p.description,
      'cover_item_id', p.cover_item_id, 'visibility', p.visibility,
      'upload_year', p.upload_year, 'created_at', p.created_at, 'updated_at', p.updated_at
    ),
    'owner', (
      select jsonb_build_object('id', o.id, 'username', o.username, 'full_name', o.full_name,
                                'avatar_key', o.avatar_key, 'year_of_study', o.year_of_study,
                                'status', o.status)
      from public.profiles o where o.id = p.user_id
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', i.id, 'type', i.type, 'storage_key', i.storage_key,
               'embed_provider', i.embed_provider, 'embed_id', i.embed_id,
               'width', i.width, 'height', i.height, 'position', i.position)
             order by i.position)
      from public.portfolio_items i
      where i.portfolio_id = p.id and i.review_state = 'live'
    ), '[]'::jsonb),
    'tags', coalesce((
      select jsonb_agg(t.name order by t.name)
      from public.portfolio_tags pt join public.tags t on t.id = pt.tag_id
      where pt.portfolio_id = p.id
    ), '[]'::jsonb),
    'credits', coalesce((
      select jsonb_agg(jsonb_build_object(
               'profile_id', c.profile_id, 'username', cp.username,
               'external_name', c.external_name, 'role', c.role))
      from public.portfolio_credits c
      left join public.profiles cp on cp.id = c.profile_id
      where c.portfolio_id = p.id and c.status = 'accepted'
    ), '[]'::jsonb),
    'like_count', (select count(*) from public.likes l where l.portfolio_id = p.id),
    'comments', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', cm.id, 'user_id', cm.user_id, 'username', cu.username,
               'content', cm.content, 'created_at', cm.created_at)
             order by cm.created_at)
      from public.comments cm
      left join public.profiles cu on cu.id = cm.user_id
      where cm.portfolio_id = p.id and not cm.hidden
    ), '[]'::jsonb)
  )
  from public.portfolios p
  where p.slug = p_slug
    and p.status = 'active'
    and p.visibility in ('public', 'unlisted');
$$;

-- Visitors and signed-in users may call it (it only returns approved work).
revoke execute on function public.get_portfolio_by_slug(text) from public;
grant  execute on function public.get_portfolio_by_slug(text) to anon, authenticated;
