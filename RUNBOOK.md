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

### Never

- Never run `supabase db reset` with `--linked` (it wipes the hosted database).
- Never commit `.env.local`, database passwords or the service-role key.
