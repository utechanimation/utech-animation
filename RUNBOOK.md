# Runbook

How to look after UTech's Animation day to day. Each section is a short checklist.
More sections (moderators, approvals, backups, keys, storage) will be added as those
features are built.

---

## Database changes

The database is defined only by the files in `supabase/migrations/`. The Supabase
dashboard must never be the only place a change exists, or the next maintainer
cannot rebuild it.

### Make a change

1. Start Docker Desktop, then start the local database:
   ```bash
   supabase start
   ```
2. Create a new migration file. Never edit a migration that has already been
   applied to the hosted project; add a new one instead.
   ```bash
   supabase migration new short_description_of_change
   ```
3. Write the SQL in the new file. Keep it small and add a comment above each
   policy or function saying who may do what and why.
   - Every new table: `alter table ... enable row level security;`, then
     `revoke all ... from anon, authenticated;` and grant back only the columns needed.
   - Students must never get a grant on `status`, `review_state`, `role`,
     `storage_used`, `hidden` or the moderation tables. Those changes go through
     `security definer` functions that check the role and write `audit_log`.
4. Rebuild the local database from zero and run the tests:
   ```bash
   supabase db reset
   supabase test db
   ```
   Add a test in `supabase/tests/` for anything that protects data.
5. Open a pull request. Paste the `supabase test db` output into it.

### Apply it to the hosted project (after the pull request is approved)

1. Link the CLI to the hosted project once (asks for the database password, which
   is in the shared Bitwarden vault; never paste it into a file):
   ```bash
   supabase link --project-ref <project-ref>
   ```
2. Check what will run, then apply it:
   ```bash
   supabase db push --dry-run
   supabase db push
   ```

### Manual steps the migrations cannot do

- **Sign-up hook.** In the Supabase dashboard go to **Authentication → Hooks →
  Before User Created**, choose **Postgres function**, and pick
  `public.hook_before_user_created`. (Locally it is already switched on in
  `supabase/config.toml`.)
- **First admin.** See "Making Someone an Admin" in `README.md`.
- **Turn off email sign-up.** Once "Sign in with Microsoft" works on the hosted
  project, go to **Authentication → Sign In / Providers → Email** and disable the
  Email provider, so nobody can sign up with an email and password. (The demo
  sign-in form needs it until then.)

### Rules for app code that reads the database

- **List columns explicitly on `profiles` and `portfolios`. Never `select('*')`.**
  Some columns are deliberately not granted (`profiles.storage_used` for everyone;
  `portfolios.reviewed_by`, `has_pending_media` and `rejection_reason` for
  visitors). Asking for `*` asks for those columns too, and Postgres then refuses
  the whole query with "permission denied".

### Who can read profiles (temporary rule)

Until a final decision in Phase 3/4, a profile row is readable only:
- by visitors and other students, if the person **owns an active public
  portfolio** or has an **accepted credit on one** (`profile_is_public()`);
- by the person themself;
- by moderators and admins (all profiles).

Pending, rejected, private, unlisted-only or taken-down work does not make a
profile readable. `get_portfolio_by_slug()` still returns the owner's card for an
unlisted portfolio opened by its link.

What this means for app code:
- **Do not check whether a username is taken by reading `profiles`.** Most
  profiles are invisible, so the check would say "free" and the save would then
  fail on the unique constraint. Try the update and handle the unique-violation
  error (23505), or add a server-side check.
- **Decisions needed in Phase 3:** the credit picker (how to find a classmate
  who has no published work yet) and how to show the author of a comment whose
  profile is not readable.

### Comment rate limit

At most 10 comments per user per 10 minutes (brief 4.6), enforced by the
`comments_rate_limit` trigger. The 11th insert fails with error code **54000** and
the message "Too many comments. Please wait a few minutes." Show that message to
the user. Known gaps, to revisit in Phase 3: deleting a comment frees quota, and
moderators are not exempt.

### Never

- Never run `supabase db reset` with `--linked` (it wipes the hosted database).
- Never commit `.env.local`, database passwords or the service-role key.
