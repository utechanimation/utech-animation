# Task 01: Phase 1 step 1 — database migrations

Manager: Claude (claude.ai). Builder: Claude Code on the maintainer's computer. Reviewer: Claude (claude.ai), from the diff or pull request.

Read first: `docs/UTECH_ANIMATION_PROJECT_BRIEF.md` (sections 4, 5, 6 and 9) and the repo's `AGENTS.md`. The brief is the source of truth. If anything here or in the repo conflicts with it, stop and ask instead of changing course.

## Goal

Add `supabase/migrations/*.sql` so the whole database (tables, RLS, functions, triggers, seed data, storage buckets) can be rebuilt from the repo, and prove with tests that anonymous users and other students cannot read pending work or change moderation fields.

## Rules (non-negotiable)

- Zero cost. Free tiers only.
- Every table has RLS enabled, with a policy comment in plain language above each policy explaining who may do what and why.
- Students and moderators never write `status`, `review_state`, `role`, `storage_used`, `hidden` or any moderation table directly. Those writes go through `security definer` functions that set `search_path`, check the caller's role, and write to `audit_log`.
- No service-role key in any client code. Do not add it to `.env.example` as a `NEXT_PUBLIC_` value.
- Database changes live only in `supabase/migrations`, never only in the dashboard.
- Boring and well commented. A future student maintainer must be able to follow it. One concern per file.
- Do not change application code in this task, except what is needed to keep lint, type-check and build passing. No new dependencies.

## Branch

Work on a branch named `phase1/01-migrations`. Open a pull request into `main`. Do not push to `main`.

## Files to create (suggested order, one migration each)

1. `..._tables.sql`: tables and constraints exactly as in brief section 5 (profiles, staff_invites, portfolios, portfolio_items, tags, portfolio_tags, portfolio_credits, likes, comments, reports, warnings, takedowns, audit_log). `uuid` keys, `timestamptz`, check constraints for lengths and allowed values. `admin_roles` from the demo is replaced by `profiles.role`.
2. `..._role_helpers.sql`: `is_moderator()` and `is_admin()` as `security definer` functions reading the current user's role.
3. `..._rls.sql`: RLS policies as in brief section 5 ("Key RLS rules"). Public read of active public portfolios, live items, accepted credits, visible comments. Owners update only title, description, visibility, tag links and item order (use column-level grants or move these writes into functions). Moderators read everything but change state only through functions.
4. `..._triggers.sql`: max 3 tags per portfolio (brief 6.2), auto-hide a comment after 3 pending reports from 3 different users (brief 6.3), keep `updated_at` current.
5. `..._auth_hook.sql`: "Before User Created" hook (brief 6.1). Allow `@students.utech.edu.jm`, or an unused `staff_invites` email. Add the grants and revokes. Create a profile row on first sign-in. Note in a comment that the hook must be enabled by hand in Supabase under Auth → Hooks.
6. `..._moderation_functions.sql`: `approve_portfolio`, `reject_portfolio` (reason required), `approve_item`, `issue_warning`, `take_down`, `submit_appeal`, `decide_appeal`, `submit_counter_statement`, `resolve_report`, `restore_comment`. Each checks the caller's role (or ownership and current status for student functions) and writes `audit_log`.
7. `..._seed_and_storage.sql`: seed the five fixed tags (3D Modelling, Character Design, Graphic Design, Illustration, Video Editing). Create buckets `media-private` and `media-public` with storage policies: private objects readable only by their owner and moderators, public bucket readable by everyone, writes only through the server.

Before applying anything, check the current Supabase docs for the auth hook syntax, storage policy syntax and `@supabase/ssr` details, because they change. Say in the pull request what you checked.

## Tests (required)

Add `supabase/tests/` SQL tests (pgTAP or plain SQL scripts, whichever the Supabase CLI supports in the current version) showing:
- An anonymous user cannot read a `pending_review` or `rejected` portfolio, its items, or private storage objects.
- A different student cannot read or edit another student's pending portfolio.
- A student cannot set `status`, `review_state`, `role` or `storage_used` on their own rows, directly or via update.
- A student cannot call the moderator functions; a moderator can, and each call writes `audit_log`.
- A fourth tag on a portfolio is rejected.
- Three reports from three different users hide a comment; two do not; the same user reporting twice does not count twice.
- A non-student email without an invite is rejected by the hook function.

## How to run and test

Use the Supabase CLI. Prefer a local database (`supabase start`, needs Docker) and `supabase db reset` to apply all migrations from scratch. Do not run migrations against the hosted project until the review is approved. Never print or commit database passwords, keys or `.env.local`.

## Definition of done

- `supabase db reset` applies every migration cleanly from empty.
- All tests pass, and the test output is pasted in the pull request.
- `npm run lint`, type-check and `npm run build` still pass.
- `grep -r "service_role" src` finds nothing.
- Pull request description lists each table, each policy, each function, and anything uncertain or deliberately left out.
- `README.md` has a short "Database" section: how to run migrations and tests. `RUNBOOK.md` is created if missing, with a "Database changes" heading.

## Out of scope

Application code for sign-in, uploads or the review queue (later Phase 1 steps), storage-quota enforcement in code, Cloudflare R2, GitHub Actions.
