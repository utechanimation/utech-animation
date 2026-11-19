-- =============================================================================
-- Moderation functions (RPC)
-- =============================================================================
-- Students and moderators cannot write status, review_state, role, hidden or
-- the moderation tables (warnings, takedowns, reports.status, audit_log) - they
-- have no grant (see *_rls.sql). Every such change goes through one of these
-- functions. Call them from the app with supabase.rpc('approve_portfolio', {...}).
--
-- Every function:
--   * is "security definer" (runs with the owner's rights, so it can write what
--     the caller cannot) with search_path = '' and schema-qualified names;
--   * checks WHO is calling first (is_moderator(), is_admin(), or ownership);
--   * checks the CURRENT STATE, so a decision cannot be applied twice;
--   * writes one row to audit_log.
--
-- Errors: "not allowed" uses error code 42501 (insufficient_privilege), so the
-- app can tell it apart from "wrong state" errors (P0001).
--
-- Storage: these functions change database rows only. Copying approved files
-- from media-private to media-public, and deleting replaced files, is done by
-- server code (a later task), which calls these functions.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Internal helpers (not callable from the app)
-- -----------------------------------------------------------------------------

-- Write one audit_log row for the current user.
create or replace function public.write_audit(
  p_action text, p_target_type text, p_target_id uuid, p_details jsonb default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (actor_id, action, target_type, target_id, details)
  values ((select auth.uid()), p_action, p_target_type, p_target_id, p_details);
$$;

-- Stop unless the caller is a moderator or admin.
create or replace function public.require_moderator()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_moderator() then
    raise exception 'Only moderators can do this' using errcode = '42501';
  end if;
end;
$$;

-- Stop unless the caller owns the portfolio.
create or replace function public.require_portfolio_owner(p_portfolio_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.portfolios
                 where id = p_portfolio_id and user_id = (select auth.uid())) then
    raise exception 'You can only do this for your own portfolio' using errcode = '42501';
  end if;
end;
$$;


-- =============================================================================
-- Approval workflow (moderators) - brief 4.3
-- =============================================================================

-- Approve a new (or resubmitted) portfolio: it goes live, with its media.
create or replace function public.approve_portfolio(p_portfolio_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_moderator();

  update public.portfolios
     set status = 'active', rejection_reason = null, has_pending_media = false,
         reviewed_by = (select auth.uid()), reviewed_at = now()
   where id = p_portfolio_id and status = 'pending_review';
  if not found then
    raise exception 'Portfolio is not waiting for review';
  end if;

  -- The media submitted with a new portfolio is approved together with it.
  update public.portfolio_items
     set review_state = 'live'
   where portfolio_id = p_portfolio_id and review_state = 'pending';

  perform public.write_audit('approve_portfolio', 'portfolio', p_portfolio_id);
end;
$$;

-- Reject a portfolio with a reason. The student can edit it and resubmit.
create or replace function public.reject_portfolio(p_portfolio_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_moderator();

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required';
  end if;

  update public.portfolios
     set status = 'rejected', rejection_reason = btrim(p_reason),
         reviewed_by = (select auth.uid()), reviewed_at = now()
   where id = p_portfolio_id and status = 'pending_review';
  if not found then
    raise exception 'Portfolio is not waiting for review';
  end if;

  perform public.write_audit('reject_portfolio', 'portfolio', p_portfolio_id,
                             jsonb_build_object('reason', btrim(p_reason)));
end;
$$;

-- Approve one pending media item on an already-approved portfolio. If it
-- replaces a live item, the old item is deleted (its file is removed by server code).
create or replace function public.approve_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.portfolio_items;
begin
  perform public.require_moderator();

  update public.portfolio_items
     set review_state = 'live'
   where id = p_item_id and review_state = 'pending'
  returning * into v_item;
  if not found then
    raise exception 'Item is not waiting for review';
  end if;

  if v_item.replaces_item_id is not null then
    delete from public.portfolio_items where id = v_item.replaces_item_id;
  end if;

  -- Clear the "has pending media" flag once nothing is left to review.
  update public.portfolios
     set has_pending_media = exists (
           select 1 from public.portfolio_items
           where portfolio_id = v_item.portfolio_id and review_state = 'pending')
   where id = v_item.portfolio_id;

  perform public.write_audit('approve_item', 'portfolio_item', p_item_id,
    jsonb_build_object('portfolio_id', v_item.portfolio_id,
                       'replaced_item_id', v_item.replaces_item_id));
end;
$$;


-- =============================================================================
-- Warnings (moderators issue, owners answer)
-- =============================================================================

-- Warn the owner of a portfolio for 3, 7 or 14 days.
create or replace function public.issue_warning(
  p_portfolio_id uuid, p_reason text, p_duration_days int)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_warning_id uuid;
begin
  perform public.require_moderator();

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required';
  end if;
  if not exists (select 1 from public.portfolios where id = p_portfolio_id) then
    raise exception 'Portfolio not found';
  end if;

  -- duration_days is checked by the table (3, 7 or 14).
  insert into public.warnings (portfolio_id, reason, duration_days, expires_at, created_by)
  values (p_portfolio_id, btrim(p_reason), p_duration_days,
          now() + make_interval(days => p_duration_days), (select auth.uid()))
  returning id into v_warning_id;

  perform public.write_audit('issue_warning', 'portfolio', p_portfolio_id,
    jsonb_build_object('warning_id', v_warning_id, 'reason', btrim(p_reason),
                       'duration_days', p_duration_days));
  return v_warning_id;
end;
$$;

-- The portfolio owner answers a warning, once, while it is open.
create or replace function public.submit_counter_statement(p_warning_id uuid, p_statement text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
begin
  select portfolio_id into v_portfolio_id from public.warnings where id = p_warning_id;
  if v_portfolio_id is null then
    raise exception 'Warning not found';
  end if;
  perform public.require_portfolio_owner(v_portfolio_id);

  if p_statement is null or btrim(p_statement) = '' then
    raise exception 'A statement is required';
  end if;

  update public.warnings
     set counter_statement = btrim(p_statement)
   where id = p_warning_id and counter_statement is null and resolved_at is null;
  if not found then
    raise exception 'This warning already has a statement or is closed';
  end if;

  perform public.write_audit('submit_counter_statement', 'warning', p_warning_id,
                             jsonb_build_object('portfolio_id', v_portfolio_id));
end;
$$;


-- =============================================================================
-- Takedowns and appeals
-- =============================================================================

-- Take a portfolio down (hide it) with a required reason.
create or replace function public.take_down(p_portfolio_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_takedown_id uuid;
begin
  perform public.require_moderator();

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required';
  end if;

  update public.portfolios
     set status = 'taken_down'
   where id = p_portfolio_id
     and status not in ('taken_down', 'pending_appeal', 'denied_appeal');
  if not found then
    raise exception 'Portfolio not found or already taken down';
  end if;

  insert into public.takedowns (portfolio_id, reason, created_by)
  values (p_portfolio_id, btrim(p_reason), (select auth.uid()))
  returning id into v_takedown_id;

  perform public.write_audit('take_down', 'portfolio', p_portfolio_id,
    jsonb_build_object('takedown_id', v_takedown_id, 'reason', btrim(p_reason)));
  return v_takedown_id;
end;
$$;

-- The owner appeals a takedown. Only one appeal per takedown.
create or replace function public.submit_appeal(p_takedown_id uuid, p_message text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_portfolio_id uuid;
begin
  select portfolio_id into v_portfolio_id from public.takedowns where id = p_takedown_id;
  if v_portfolio_id is null then
    raise exception 'Takedown not found';
  end if;
  perform public.require_portfolio_owner(v_portfolio_id);

  if p_message is null or btrim(p_message) = '' then
    raise exception 'An appeal message is required';
  end if;

  update public.takedowns
     set appeal_message = btrim(p_message), appeal_status = 'pending'
   where id = p_takedown_id and appeal_status = 'none' and resolved_at is null;
  if not found then
    raise exception 'This takedown has already been appealed';
  end if;

  update public.portfolios
     set status = 'pending_appeal'
   where id = v_portfolio_id and status = 'taken_down';

  perform public.write_audit('submit_appeal', 'takedown', p_takedown_id,
                             jsonb_build_object('portfolio_id', v_portfolio_id));
end;
$$;

-- Decide an appeal.
--   approve = true : the portfolio goes back to 'active'.
--   approve = false: the portfolio is locked ('denied_appeal') and scheduled for
--                    deletion in 1 year (the deletion job is a later task).
-- Admin override: an admin may still approve an appeal that was denied.
create or replace function public.decide_appeal(p_takedown_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_takedown public.takedowns;
begin
  perform public.require_moderator();

  select * into v_takedown from public.takedowns where id = p_takedown_id for update;
  if not found then
    raise exception 'Takedown not found';
  end if;

  if not (v_takedown.appeal_status = 'pending'
          or (v_takedown.appeal_status = 'denied' and p_approve and public.is_admin())) then
    raise exception 'There is no open appeal to decide';
  end if;

  if p_approve then
    update public.takedowns
       set appeal_status = 'approved', resolved_at = now(), scheduled_wipe_at = null
     where id = p_takedown_id;
    update public.portfolios set status = 'active' where id = v_takedown.portfolio_id;
  else
    update public.takedowns
       set appeal_status = 'denied', appeal_denied_at = now(),
           scheduled_wipe_at = now() + interval '1 year'
     where id = p_takedown_id;
    update public.portfolios set status = 'denied_appeal' where id = v_takedown.portfolio_id;
  end if;

  perform public.write_audit(
    case when p_approve then 'approve_appeal' else 'deny_appeal' end,
    'takedown', p_takedown_id,
    jsonb_build_object('portfolio_id', v_takedown.portfolio_id,
                       'admin_override', v_takedown.appeal_status = 'denied'));
end;
$$;


-- =============================================================================
-- Reports and comments
-- =============================================================================

-- Close a report: 'reviewed', 'actioned' or 'dismissed'.
create or replace function public.resolve_report(p_report_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_moderator();

  if p_status not in ('reviewed', 'actioned', 'dismissed') then
    raise exception 'Status must be reviewed, actioned or dismissed';
  end if;

  update public.reports set status = p_status where id = p_report_id;
  if not found then
    raise exception 'Report not found';
  end if;

  perform public.write_audit('resolve_report', 'report', p_report_id,
                             jsonb_build_object('status', p_status));
end;
$$;

-- Show a hidden comment again. Its pending reports are dismissed, otherwise the
-- next report would hide it again straight away.
create or replace function public.restore_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_moderator();

  update public.comments set hidden = false where id = p_comment_id;
  if not found then
    raise exception 'Comment not found';
  end if;

  update public.reports set status = 'dismissed'
   where comment_id = p_comment_id and status = 'pending';

  perform public.write_audit('restore_comment', 'comment', p_comment_id);
end;
$$;

-- Delete a comment (the "delete" choice when reviewing a hidden comment).
-- Its reports are deleted with it; the audit_log row keeps the text.
create or replace function public.delete_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_comment public.comments;
begin
  perform public.require_moderator();

  delete from public.comments where id = p_comment_id returning * into v_comment;
  if not found then
    raise exception 'Comment not found';
  end if;

  perform public.write_audit('delete_comment', 'comment', p_comment_id,
    jsonb_build_object('portfolio_id', v_comment.portfolio_id,
                       'author_id', v_comment.user_id, 'content', v_comment.content));
end;
$$;


-- =============================================================================
-- Students: resubmit after rejection
-- =============================================================================

-- After editing a rejected portfolio, the owner sends it back to the review queue.
create or replace function public.resubmit_portfolio(p_portfolio_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_portfolio_owner(p_portfolio_id);

  update public.portfolios
     set status = 'pending_review'
   where id = p_portfolio_id and status = 'rejected';
  if not found then
    raise exception 'Only a rejected portfolio can be resubmitted';
  end if;

  perform public.write_audit('resubmit_portfolio', 'portfolio', p_portfolio_id);
end;
$$;


-- =============================================================================
-- Admins: change someone's role (brief 4.1, e.g. promote the student rep)
-- =============================================================================
create or replace function public.set_user_role(p_user_id uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_role text;
begin
  if not public.is_admin() then
    raise exception 'Only admins can change roles' using errcode = '42501';
  end if;
  if p_role not in ('student', 'moderator', 'admin') then
    raise exception 'Role must be student, moderator or admin';
  end if;
  if p_user_id = (select auth.uid()) then
    raise exception 'Admins cannot change their own role';
  end if;

  select role into v_old_role from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'User not found';
  end if;

  update public.profiles set role = p_role where id = p_user_id;

  perform public.write_audit('set_user_role', 'profile', p_user_id,
    jsonb_build_object('old_role', v_old_role, 'new_role', p_role));
end;
$$;


-- =============================================================================
-- Who may call what
-- =============================================================================
-- Internal helpers: nobody calls these directly.
revoke execute on function public.write_audit(text, text, uuid, jsonb)  from public, anon, authenticated;
revoke execute on function public.require_moderator()                   from public, anon, authenticated;
revoke execute on function public.require_portfolio_owner(uuid)         from public, anon, authenticated;

-- App functions: signed-in users only. Each function checks the role itself.
revoke execute on function
  public.approve_portfolio(uuid), public.reject_portfolio(uuid, text),
  public.approve_item(uuid), public.issue_warning(uuid, text, int),
  public.submit_counter_statement(uuid, text), public.take_down(uuid, text),
  public.submit_appeal(uuid, text), public.decide_appeal(uuid, boolean),
  public.resolve_report(uuid, text), public.restore_comment(uuid),
  public.delete_comment(uuid), public.resubmit_portfolio(uuid),
  public.set_user_role(uuid, text)
from public, anon;

grant execute on function
  public.approve_portfolio(uuid), public.reject_portfolio(uuid, text),
  public.approve_item(uuid), public.issue_warning(uuid, text, int),
  public.submit_counter_statement(uuid, text), public.take_down(uuid, text),
  public.submit_appeal(uuid, text), public.decide_appeal(uuid, boolean),
  public.resolve_report(uuid, text), public.restore_comment(uuid),
  public.delete_comment(uuid), public.resubmit_portfolio(uuid),
  public.set_user_role(uuid, text)
to authenticated;
