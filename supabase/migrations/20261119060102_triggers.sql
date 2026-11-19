-- =============================================================================
-- Triggers
-- =============================================================================
--   1. portfolio_tags_max_three   - a portfolio may have at most 3 tags (brief 6.2)
--   2. reports_auto_hide          - 3 pending reports from 3 different users hide
--                                   a comment until a moderator reviews it (brief 6.3)
--   3. portfolios_set_updated_at  - keep portfolios.updated_at current
--   4. portfolio_credits_set_status - new credits start as 'invited' (students on the
--                                   platform) or 'accepted' (external names)
--
-- Trigger functions that must see or change rows the caller cannot (other
-- users' reports, comments.hidden) are "security definer" with an empty
-- search_path and schema-qualified names.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. At most 3 tags per portfolio (brief 4.5 and 6.2)
-- -----------------------------------------------------------------------------
-- Changed from the brief's snippet: it locks the portfolio row first, so two tags
-- added at the same moment cannot both slip past the count.
create or replace function public.enforce_max_three_tags()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Wait for any other transaction adding tags to the same portfolio.
  perform 1 from public.portfolios where id = new.portfolio_id for update;

  if (select count(*) from public.portfolio_tags
      where portfolio_id = new.portfolio_id) >= 3 then
    raise exception 'A portfolio can have at most 3 tags';
  end if;
  return new;
end;
$$;

create trigger portfolio_tags_max_three
  before insert on public.portfolio_tags
  for each row execute function public.enforce_max_three_tags();


-- -----------------------------------------------------------------------------
-- 2. Auto-hide a comment after 3 pending reports from 3 different users
-- -----------------------------------------------------------------------------
-- The unique (reporter_id, comment_id) constraint on reports already stops the
-- same user reporting a comment twice; "count(distinct reporter_id)" makes the
-- rule clear anyway. An admin restores the comment with restore_comment().
create or replace function public.auto_hide_reported_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.comment_id is not null and
     (select count(distinct reporter_id) from public.reports
      where comment_id = new.comment_id and status = 'pending') >= 3 then
    update public.comments set hidden = true where id = new.comment_id;
  end if;
  return new;
end;
$$;

create trigger reports_auto_hide
  after insert on public.reports
  for each row execute function public.auto_hide_reported_comment();


-- -----------------------------------------------------------------------------
-- 3. Keep portfolios.updated_at current on every change
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger portfolios_set_updated_at
  before update on public.portfolios
  for each row execute function public.set_updated_at();


-- -----------------------------------------------------------------------------
-- 4. New credits: 'invited' for a student on the platform, 'accepted' for an
--    external name (they cannot accept anything). Users cannot set status.
-- -----------------------------------------------------------------------------
create or replace function public.set_new_credit_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.profile_id is null then
    new.status := 'accepted';
  else
    new.status := 'invited';
  end if;
  return new;
end;
$$;

create trigger portfolio_credits_set_status
  before insert on public.portfolio_credits
  for each row execute function public.set_new_credit_status();


-- Trigger functions are only run by their triggers, never called directly.
revoke execute on function public.enforce_max_three_tags()     from public, anon, authenticated;
revoke execute on function public.auto_hide_reported_comment() from public, anon, authenticated;
revoke execute on function public.set_updated_at()             from public, anon, authenticated;
revoke execute on function public.set_new_credit_status()      from public, anon, authenticated;
