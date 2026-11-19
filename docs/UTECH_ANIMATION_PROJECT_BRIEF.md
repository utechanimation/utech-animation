# UTech Animation Portfolio Gallery — Project Brief for Claude

> **How to use this file:** Give this file to Claude together with the existing repo
> (`utech-animation-main`). It holds every decision made so far. Claude should treat
> the decisions here as settled and ask before changing any of them.

---

## 1. What we are building

A web app where **animation students at the University of Technology, Jamaica (UTech)**
post, store and show their work in portfolios, like Behance for one department.

- **Core action:** a student uploads work and gets a **shareable portfolio link**.
- **Visitors:** students who upload, plus the general public, who browse without an account.
- **Devices:** most people use a **phone**. Design mobile-first.
- **Scale:** one university, one department. At most about **400 students**, about 50 per year group.
- **Budget:** **zero cost.** Everything must run on free tiers.
- **Handover:** the person building it will **not** maintain it. Code must be simple, boring,
  well-documented and easy for a future student to pick up.

Priorities, in order: **security and data privacy → simplicity and maintainability → performance on phones → clean design.**

---

## 2. The existing demo, and what to do with it

The repo `utech-animation-main` is a working demo. **Evolve it; do not start over.**

### Current stack (keep)
- Next.js 16 (App Router) + React 19 + TypeScript
- Supabase (Postgres, Auth, Storage) via `@supabase/ssr`
- Tailwind CSS v4 + CSS variables, Framer Motion for animation, lucide-react for icons
- Deployed on Vercel at `utech-animation.vercel.app`
- **Read `AGENTS.md` first:** this Next.js version has breaking changes. Check
  `node_modules/next/dist/docs/` before writing Next.js code.

### Current features (keep, with the changes in section 4)
- Discovery feed: hero section, search portfolios / search profiles, year filter, tag filter, animated grid
- Public profile at `/profile/[username]`: avatar, bio, year of study, portfolio count, total likes
- Portfolio page at `/portfolio/[slug]`: cover, tags, owner card, media grid, zoom/pan lightbox, likes, comments, report button
- Student dashboard with visibility control (**Public / Unlisted / Private**) and status badges
- Settings: avatar, bio, year of study
- Admin panel at `/admin`: search and filter, **timed warnings** (3 days / 1 week / 2 weeks) with
  student counter-statements, **takedowns** with a required reason, **one appeal** per takedown,
  denied appeal → locked and deleted after 1 year, admin override, report management
  (Inappropriate Content / Copyright; Pending → Reviewed → Actioned / Dismissed)
- Terms page at `/terms`

### Design language (settled November 2026 — UI/UX revamp)
The UI was revamped from an approved storyboard. The README's **Design** section is the
working reference; this is the summary.

- **Name and logo:** "UTech's Animation" (never "Knight Cap" — that is the yearly showcase,
  this site is long-term). Logo = the **owl**: black owl, centred painter's beret, scarf,
  paintbrush tilted outward beside it (`src/components/brand/Owl.tsx`), colour and
  one-colour versions. Favicon = one-colour owl on a purple tile (`src/app/icon.svg`).
- **Colours:** dark theme. Tokens in `src/app/globals.css`:
  `--accent #a855f7` (purple text, icons, active states), `--accent-hover #9333ea`
  (fill behind white text — white on #a855f7 is too faint), `--bg #0a0a0a`,
  `--surface #141414`, `--surface-2 #1e1e1e`, `--border #2a2a2a`, `--text #fafafa`,
  `--muted #a1a1aa` for small grey text (`--muted-dim #71717a` only for large text).
  Extra purple shades `#3b0764`, `#6b21a8`, `#c084fc`, `#e9d5ff`; amber/red only for
  moderation warnings. The brand rainbow appears only on the word "Creativity." and avatar rings.
- **Fonts:** **Baloo 2** (logo, page titles, headings) + **Inter** (body), self-hosted with
  `next/font/local` from `src/app/fonts/` (SIL OFL). No runtime request to Google.
- **Shapes and motion ("alive and free"):** purple nebula with slowly drifting stars behind
  heroes, paint drips under banners, tags as tilted stickers, free-flow masonry grid,
  bouncing-ball loader, "pop" on like/copy, purple drip reveal when a portfolio opens.
  All CSS or the existing Framer Motion — no new animation libraries. Everything switches to
  simple fades with "reduce motion".
- **Phone layout:** bottom tab bar (Explore, Search, +, My work, Profile); portfolio pages
  replace it with a like / comments / copy-link bar. Touch targets ≥ 44 px. Rounded cards
  (radius 14–24), pill buttons.

### Problems found in the demo (must fix)

| # | Problem | Why it matters | Fix |
|---|---|---|---|
| 1 | **No database schema in the repo.** Tables and RLS exist only in the Supabase dashboard. | A future maintainer can't rebuild or review it. | Add `supabase/migrations/*.sql` with the Supabase CLI: every table, policy, function and trigger. |
| 2 | **Sign-up accepts any email, with a password.** | Anyone can create an account; passwords add risk. | Replace with Microsoft sign-in (section 4.1). *Revamp: the Microsoft button and `/auth/callback` exist; the old form is kept behind "Demo sign-in (temporary)" until the Azure provider and hook are set up.* |
| 3 | **Students change moderation status from the browser** (for example `DashboardClient` sets `status: 'pending_appeal'` directly). If RLS lets owners update `status`, a student could set a taken-down portfolio back to `active`. | Moderation can be bypassed. | Owners must **never** be able to write `status`, `review_state` or moderation tables directly. All status changes go through **Postgres functions (`security definer`) or server actions** that check permissions. |
| 4 | **Admin actions run from the browser** (`AdminClient` writes to `warnings`, `takedowns` and `portfolios`). | Safety depends entirely on RLS that isn't in the repo. | Move admin actions to server actions or RPC functions that check `is_admin()`. Add RLS as a second layer. |
| 5 | **Uploads go straight to a public bucket**, with no size or type checks (the "max 10MB" text is not enforced), and raw video files are accepted. | Storage fills fast; unreviewed content is public. | New media pipeline (section 4.4). |
| 6 | **Work is published immediately.** | Admins must approve uploads. | Approval workflow (section 4.3). |
| 7 | **Unlimited tags.** | The rule is at most 3. | Max 3, picked from a dropdown, enforced in the database (section 4.5). *Revamp: the upload and edit screens now stop at 3; the database check is still to do.* |
| 8 | ~~Fonts load from Google Fonts at runtime.~~ | — | **Done in the revamp:** self-hosted with `next/font/local`. |
| 9 | **Mixed styling:** heavy inline `style={{}}` objects. | Hard to maintain. | **Partly done:** Tailwind v4 (`@import "tailwindcss"`) with the CSS variables as theme tokens; revamped screens use classes. Settings, edit and admin still use inline styles — move them over when you touch those files. |
| 10 | ~~README mentions `.env.example`, but it doesn't exist.~~ | — | **Done:** `.env.example` added. |

---

## 3. Stack and free-tier budget

| Concern | Service | Free-tier note |
|---|---|---|
| App hosting | **Vercel Hobby** | Non-commercial use only. An ad-free student showcase fits. Fallback: Cloudflare Workers free plan. |
| Database + auth | **Supabase Free** | 500 MB DB, 1 GB file storage (50 MB max per file), 5 GB egress, 50k MAU. **Pauses after 7 days with no activity** and has **no backups**; see section 7. |
| Media storage | **Phase 1 (demo): Supabase Storage. Later: Cloudflare R2** (10 GB free, no egress fees) | R2 asks for a card on file and has no hard spending cap, so app-level quotas are required. Hide storage behind `src/lib/storage.ts` so switching is a one-file change. |
| Full-length video | **YouTube (unlisted is fine) or Vimeo links**, embedded | Free, unlimited, plays at lower quality on mobile data. The site never stores full videos. |
| Login | **Microsoft (Azure) via Supabase Auth**, plus Google for graduates | No emails sent by the app, so no email provider or domain is needed. |
| Analytics | None, or Cloudflare Web Analytics (cookie-free) | No tracking cookies. |

**Why video is handled this way:** 1080p60 is about 205 MB per minute. 10 GB holds about 50 minutes of video
for the whole department, so hosting full videos ourselves isn't possible at $0.

---

## 4. Product decisions (settled)

### 4.1 Accounts and sign-in
- **Students** sign in with **"Sign in with Microsoft"** using their UTech M365 account.
  - Only emails ending in **`@students.utech.edu.jm`** may create an account.
  - Enforce this **on the server** with a Supabase **"Before User Created" auth hook** (section 6.1).
    A browser-side check alone is not security.
  - Use the Supabase Azure provider and follow Supabase's Azure guide, **including the steps for a
    verified email claim** (`xms_edov`), so a fake email from another Microsoft tenant can't pass.
  - **Test early:** UTech's M365 admins may block student consent for third-party apps. If so,
    the IT team must approve the app once.
- **Lecturers** (moderators) don't have `@students...` emails. An admin adds their email to
  `staff_invites`. That email may then sign up, and it gets the role from the invite.
- **The student rep** signs up as a normal student; an admin promotes them to moderator.
- **Graduates:** in Settings, any student can **link a personal Google or Microsoft account**
  (Supabase manual identity linking). After graduation they sign in with it, and their profile shows
  **alumni**. Final-year students (year 4+) see a dashboard banner reminding them to link one.
  **Graduates can keep uploading** (still approved by moderators).
- Remove email/password sign-up and the old `/login` form.

### 4.2 Portfolios
- **Keep the demo's model:** a **profile has many portfolios**; a portfolio has a cover,
  title, description, up to 3 tags, and many **media items** (`portfolio_items`).
- Shareable links: `/profile/[username]` (all of a student's portfolios) and
  `/portfolio/[slug]` (one portfolio). Keep these URLs.
- Visibility stays **Public / Unlisted (link only) / Private**.

### 4.3 Approval workflow (new)
- **New portfolio** → status `pending_review`. It is not visible to the public until a moderator
  **approves** it (→ `active`) or **rejects** it with a reason (→ `rejected`; the student can edit and resubmit).
- **Edits:**
  - **Text** (title, description, tags, visibility): goes live **immediately**, with no re-approval.
  - **Media** (new, replaced or reordered cover or items): the new item gets `review_state = 'pending'`.
    **The approved version stays live** until a moderator approves the change, so a shared link
    never breaks. On approval the new item goes live and any replaced item is deleted.
- Moderators see one **Review queue**: new portfolios and pending media, oldest first.
- Every approve, reject, warn, takedown and appeal decision is written to `audit_log`.
- Keep the demo's post-publication moderation (warnings, takedowns, appeals) on top of this.

### 4.4 Media rules
| Type | Rule | Stored where |
|---|---|---|
| Image | Compressed **in the browser** to WebP before upload: max 2560 px long edge, plus **1280 px** and **480 px** versions. Re-encoding also strips EXIF/GPS metadata, which matters for privacy. | Storage |
| Loop | MP4, **≤ 15 seconds, ≤ 15 MB**, plays muted, autoplays and loops (like a GIF, but about 10× smaller). Check duration in the browser and size on the server. | Storage |
| Video | A **YouTube or Vimeo URL** only. Allow only those hosts; save the video ID, not raw HTML. Embed through `youtube-nocookie.com` / `player.vimeo.com`, and load the iframe only **after the visitor taps a poster image** (a light "facade" embed). | Link only |

- **Quota: 50 MB per student**, counting every stored file including the avatar.
  The server checks the quota before issuing any upload URL.
- **Uploads are server-controlled:** the client asks a server route for a signed upload URL; the
  server checks login, file type, declared size and quota; the client uploads; the server confirms
  the object's real size, then creates the database row.
- **Two buckets:** `media-private` (pending work, viewed only through short-lived signed URLs by
  the owner and moderators) and `media-public` (approved work only). Approval copies the object
  from private to public. **Unapproved work is never at a public URL.**
- The admin panel shows **total storage used** (warn at 80% of the free tier).

### 4.5 Tags
- Picked from a **dropdown or multi-select. Never typed.** Fixed list:
  **3D Modelling, Character Design, Graphic Design, Illustration, Video Editing**
- **1 to 3 tags per portfolio**, enforced in the database (section 6.2).
- Tags power the Explore filter and search. Only admins can add tags to the list later.

### 4.6 Likes and comments
- Anyone can **view** likes and comments. Only **logged-in** users can like or comment
  (so only UTech students, staff and linked alumni).
- One like per user per portfolio.
- **Comments appear immediately.** Every comment has a **Report** button.
- **3 reports from 3 different users auto-hide a comment** until an admin reviews it
  (restore or delete). Enforced with a trigger (section 6.3).
- Comments: max 1000 characters; rate-limit 10 comments per user per 10 minutes.

### 4.7 Group projects (collaborators)
- The owner can credit other students on a portfolio, giving each a role
  (for example "Rigging", "Background art"). External people are plain-text names.
- A credited student gets an **invite** in their dashboard: **Accept / Decline**.
- **A collaborator's name appears on the portfolio, and the portfolio appears on their
  profile, only after they accept.** Declining removes the credit.

### 4.8 Privacy (data protection)
- Collect only: name, UTech email, username, year of study, bio, avatar, and the work.
- **Settings → "Download my data"** (JSON + file links) and **"Delete my account"**, which
  deletes the profile, portfolios, comments, likes **and all stored files**.
- No tracking cookies, no third-party scripts until a visitor taps play on a video.
- Choose the Supabase region closest to Jamaica (US East).
- A plain-language **Privacy Policy** page (data collected, why, who sees it, how to delete it,
  contact). It should follow Jamaica's **Data Protection Act, 2020**; have UTech review it.
- Keep `/terms` and add **Content Guidelines** (own work only, credit collaborators, no
  copyrighted music without rights, etc.).

---

## 5. Data model

Postgres in Supabase. All tables have RLS **enabled**. `uuid` primary keys, `timestamptz` timestamps.

```
profiles
  id               uuid PK = auth.users.id
  username         text unique, lowercase, 3–30 chars [a-z0-9_-]
  full_name        text
  bio              text ≤ 500
  avatar_key       text            -- storage key, not a full URL
  year_of_study    int 1–6
  role             text  'student' | 'moderator' | 'admin'   default 'student'
  status           text  'student' | 'alumni'                default 'student'
  storage_used     bigint default 0   -- bytes, maintained by server code
  created_at

staff_invites
  email            text PK (lowercase)
  role             text 'moderator' | 'admin'
  invited_by       uuid → profiles
  used_at          timestamptz null

portfolios
  id, user_id → profiles
  slug             text unique
  title            text ≤ 120
  description      text ≤ 3000
  cover_item_id    uuid → portfolio_items null
  visibility       text 'public' | 'unlisted' | 'private'
  status           text 'pending_review' | 'active' | 'rejected'
                        | 'taken_down' | 'pending_appeal' | 'denied_appeal'
  rejection_reason text null
  has_pending_media boolean default false
  reviewed_by      uuid → profiles null
  reviewed_at, upload_year int, created_at, updated_at

portfolio_items
  id, portfolio_id → portfolios (on delete cascade)
  type             text 'image' | 'loop' | 'video_embed'
  storage_key      text null       -- image/loop (base key; sizes derived: _480, _1280, _full)
  embed_provider   text null 'youtube' | 'vimeo'
  embed_id         text null
  width, height    int null
  bytes            bigint default 0
  position         int
  review_state     text 'pending' | 'live' | 'rejected'
  replaces_item_id uuid null       -- set when this item replaces a live one
  created_at

tags                 id, name unique  (seeded with the 5 fixed tags)
portfolio_tags       portfolio_id, tag_id   PK(both)   -- max 3 per portfolio (trigger)

portfolio_credits
  id, portfolio_id → portfolios
  profile_id       uuid → profiles null   -- a student on the platform
  external_name    text null              -- someone not on the platform
  role             text ≤ 60
  status           text 'invited' | 'accepted' | 'declined'   (external names: always 'accepted')
  check (profile_id is not null or external_name is not null)

likes                user_id, portfolio_id   PK(both), created_at
comments             id, portfolio_id, user_id, content ≤ 1000, hidden bool default false, created_at
reports
  id, reporter_id → profiles
  portfolio_id null, comment_id null     -- exactly one is set
  category         text 'inappropriate' | 'copyright' | 'harassment' | 'other'
  details          text ≤ 1000
  status           text 'pending' | 'reviewed' | 'actioned' | 'dismissed'
  unique (reporter_id, comment_id), unique (reporter_id, portfolio_id)
warnings             (keep from demo) id, portfolio_id, reason, duration_days, expires_at,
                     counter_statement, resolved_at, created_by, created_at
takedowns            (keep from demo) id, portfolio_id, reason, appeal_message, appeal_status,
                     appeal_denied_at, scheduled_wipe_at, resolved_at, created_by, created_at
audit_log            id, actor_id, action text, target_type text, target_id uuid, details jsonb, created_at
```

`admin_roles` from the demo is **replaced** by `profiles.role`. Add helpers
`is_moderator()` / `is_admin()` as `security definer` SQL functions that read the current user's role.

### Key RLS rules (in plain language)
- **Public (anon) can read:** portfolios where `status = 'active'` and `visibility = 'public'`
  (unlisted: readable by exact slug only); their `portfolio_items` where `review_state = 'live'`;
  public profile fields; tags; likes counts; comments where `hidden = false`;
  `portfolio_credits` where `status = 'accepted'`.
- **Owners can read** everything of their own. **Owners can update** only title, description,
  visibility, tags and item order. **Never** `status`, `review_state`, `role`, `storage_used` or
  moderation tables. Use column-level grants or move these writes into RPC functions.
- **Moderators and admins can read everything.** They change state **only through RPC functions**
  (`approve_portfolio`, `reject_portfolio`, `approve_item`, `issue_warning`, `take_down`,
  `decide_appeal`, `resolve_report`, `restore_comment`), and each function writes `audit_log`.
- **Students** submit appeals and counter-statements only through RPCs
  (`submit_appeal`, `submit_counter_statement`) that check ownership and current status.
- Only **admins** manage `staff_invites` and change roles.

---

## 6. Must-have database code (check against current Supabase docs before applying)

### 6.1 Email-domain check — "Before User Created" auth hook
```sql
create or replace function public.hook_before_user_created(event jsonb)
returns jsonb language plpgsql as $$
declare
  v_email text := lower(event->'user'->>'email');
begin
  if v_email like '%@students.utech.edu.jm' then
    return '{}'::jsonb;
  end if;
  if exists (select 1 from public.staff_invites
             where email = v_email and used_at is null) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'Please sign in with your UTech student Microsoft account.'));
end $$;

grant execute on function public.hook_before_user_created to supabase_auth_admin;
revoke execute on function public.hook_before_user_created from authenticated, anon, public;
grant select on public.staff_invites to supabase_auth_admin;
```
Then enable it under **Auth → Hooks**. Linking a personal identity to an existing user doesn't
create a new user, so graduates aren't blocked by this hook.

### 6.2 Max 3 tags
```sql
create or replace function public.enforce_max_three_tags()
returns trigger language plpgsql as $$
begin
  if (select count(*) from public.portfolio_tags
      where portfolio_id = new.portfolio_id) >= 3 then
    raise exception 'A portfolio can have at most 3 tags';
  end if;
  return new;
end $$;

create trigger portfolio_tags_max_three
before insert on public.portfolio_tags
for each row execute function public.enforce_max_three_tags();
```

### 6.3 Auto-hide a comment after 3 reports from different users
```sql
create or replace function public.auto_hide_reported_comment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.comment_id is not null and
     (select count(distinct reporter_id) from reports
      where comment_id = new.comment_id and status = 'pending') >= 3 then
    update comments set hidden = true where id = new.comment_id;
  end if;
  return new;
end $$;

create trigger reports_auto_hide
after insert on public.reports
for each row execute function public.auto_hide_reported_comment();
```

---

## 7. Operations (zero cost, easy to hand over)

- **Ownership:** every service account (GitHub organization, Vercel, Supabase, later Cloudflare)
  is registered to a shared Gmail account, for example `utech.animation.portfolio@gmail.com`, with 2FA on.
  All passwords and recovery codes live in a **free Bitwarden organization** shared with a
  lecturer. The handover is: add the next maintainer to the vault and GitHub organization.
- **GitHub Actions:**
  1. `ci.yml`: install, lint, type-check, build on every pull request.
  2. `keepalive.yml`: weekly request that hits the database, so the free Supabase project doesn't pause during holidays.
  3. `backup.yml`: weekly `pg_dump`, encrypted, stored privately (not in the repo).
     Supabase Free has no backups.
- **Dependabot** for dependency updates.
- **Security headers** in `next.config.ts`: Content-Security-Policy (allow frames only from
  `www.youtube-nocookie.com` and `player.vimeo.com`; images and media only from our storage domain),
  `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`.
- **Secrets:** only `NEXT_PUBLIC_SUPABASE_URL` and the anon or publishable key reach the browser.
  The service-role key is used only in server code and never imported into a client component.
- **Policy for students:** the platform is a showcase, not an archive. Students keep their master files.

### Docs to write
- `README.md`: what it is, how to run locally, how to deploy
- `RUNBOOK.md`: add or remove a moderator; invite a lecturer; approve work; what to do if the
  site is down or Supabase is paused; restore a backup; rotate keys; check storage usage;
  switch storage to R2
- `.env.example`
- Comments in SQL migrations explaining each policy

---

## 8. Performance on phones
- Thumbnails (480 px) in grids, 1280 px on portfolio pages, full size only in the lightbox.
  Use `srcset`/`sizes` and `loading="lazy"`.
- Video embeds use the poster-then-tap facade, never a live iframe in a grid.
- Loops use `<video muted autoplay loop playsinline preload="none">` with a poster, and play only when on screen.
- Public pages are server-rendered and cached. Revalidate on approval, edit or delete.
- Keep Framer Motion animations light. Respect `prefers-reduced-motion`.
- Target Lighthouse mobile performance ≥ 90 on Explore and the portfolio page.

---

## 9. Build order

**Phase 0 — UI/UX revamp (done, November 2026)**
New look from the approved storyboard (section 2, Design language): owl logo, Baloo 2 + Inter,
nebula/stars/drips/stickers, masonry grid, phone tab bar, four-step upload, restyled dashboard,
Microsoft sign-in button with a temporary demo form.

**Phase 1 — Demo milestone (the core action, start to finish)**
1. Add `supabase/migrations` with the full schema, RLS, helpers, triggers and seeded tags.
2. Microsoft sign-in plus the domain-check hook; create a profile on first login (choose a username).
3. New-portfolio form: title, description, tag dropdown (1–3), cover image and images
   (browser compression → signed upload → `media-private`). Status `pending_review`.
4. Moderator review queue: approve or reject with a reason → media copied to `media-public` → audit log.
5. Approved portfolio visible at `/portfolio/[slug]` and on `/profile/[username]`; the link works on a phone.

**Phase 2 — Showcase**
6. Explore feed with filters (tags, year, medium) and search (portfolios and profiles).
7. Loops and YouTube/Vimeo embeds; storage quota; storage meter in admin.
8. Media-edit re-approval (keep the old version live until approval).

**Phase 3 — Community and moderation**
9. Likes, comments, reports, auto-hide after 3 reports, admin restore/delete.
10. Move the demo's warnings, takedowns and appeals onto RPC functions plus the audit log.
11. Collaborator credits with accept/decline.

**Phase 4 — Privacy, accounts and handover**
12. Link personal account (alumni), final-year banner, staff invites.
13. Download my data, delete my account, Privacy Policy and Content Guidelines pages.
14. Security headers, GitHub Actions (CI, keepalive, backup), README, RUNBOOK. (Self-hosted fonts: done in Phase 0.)

### Definition of done for each phase
- Works at a 375 px width.
- Every new table has RLS policies, and **a test proves an anonymous user and a different
  student cannot read pending work or change status.**
- No service-role key in client code (check with grep).
- Lint, type-check and build pass.

---

## 10. Not in scope (for now)
- Email notifications (the app sends no email; status is shown in the dashboard)
- Paid features, ads, payments
- 3D model viewers (students post 3D work as images or video)
- Native mobile apps
- View counts and analytics dashboards

## 11. Still to confirm with UTech
- Whether UTech's M365 tenant allows student consent for the Microsoft sign-in app (or IT must approve it once).
- Whether UTech can give a subdomain (for example `portfolio.utech.edu.jm`). Until then, use `utech-animation.vercel.app`.
- Who at the department can own a card for Cloudflare R2 when storage outgrows Supabase's free 1 GB.
- Review of the Privacy Policy under Jamaica's Data Protection Act, 2020.
