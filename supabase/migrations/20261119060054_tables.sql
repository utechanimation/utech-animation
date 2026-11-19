-- =============================================================================
-- Tables and constraints
-- =============================================================================
-- Source of truth: docs/UTECH_ANIMATION_PROJECT_BRIEF.md, section 5 ("Data model").
--
-- This file only creates tables, constraints and indexes, and switches RLS on.
-- Who may read or write what is decided in the *_rls.sql migration.
-- Moderation changes happen only through functions in *_moderation_functions.sql.
--
-- Conventions:
--   * every primary key is a uuid; every timestamp is timestamptz
--   * allowed values are enforced with check constraints, not enums, so a future
--     maintainer can change a list with a simple "alter table ... drop/add constraint"
--   * "admin_roles" from the demo is replaced by profiles.role
-- =============================================================================


-- -----------------------------------------------------------------------------
-- profiles: one row per signed-up person (same id as auth.users)
-- -----------------------------------------------------------------------------
create table public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  -- Chosen by the student after first sign-in, so it is empty (null) until then.
  username       text unique
                 check (username ~ '^[a-z0-9_-]{3,30}$'),
  full_name      text check (char_length(full_name) <= 120),
  bio            text check (char_length(bio) <= 500),
  -- Storage key, not a full URL. It must sit in the user's own folder
  -- ("<their id>/..."), so a user cannot point their avatar at someone else's file.
  avatar_key     text check (avatar_key is null or starts_with(avatar_key, id::text || '/')),
  year_of_study  int  check (year_of_study between 1 and 6),
  role           text not null default 'student'
                 check (role in ('student', 'moderator', 'admin')),
  status         text not null default 'student'
                 check (status in ('student', 'alumni')),
  storage_used   bigint not null default 0   -- bytes, maintained by server code
                 check (storage_used >= 0),
  created_at     timestamptz not null default now()
);

comment on table public.profiles is
  'One row per user. role/status/storage_used are never written by the user directly.';


-- -----------------------------------------------------------------------------
-- staff_invites: emails (lecturers) that may sign up without a student email
-- -----------------------------------------------------------------------------
create table public.staff_invites (
  email       text primary key check (email = lower(email)),
  role        text not null check (role in ('moderator', 'admin')),
  invited_by  uuid references public.profiles (id) on delete set null,
  used_at     timestamptz                    -- set when the invited person signs up
);


-- -----------------------------------------------------------------------------
-- portfolios: a student's project page
-- -----------------------------------------------------------------------------
create table public.portfolios (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles (id) on delete cascade,
  -- Format: words from the title + '-' + exactly 10 random lowercase letters/digits,
  -- for example "night-market-short-k3x9q2m7ab". The random part keeps two
  -- portfolios with the same title apart and makes unlisted links hard to guess
  -- (36^10, about 3.6 million million possibilities). The app generates it; the
  -- database only checks the shape. Max 80 characters keeps links short.
  slug               text not null unique
                     check (char_length(slug) <= 80
                            and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*-[a-z0-9]{10}$'),
  title              text not null check (char_length(title) between 1 and 120),
  description        text check (char_length(description) <= 3000),
  cover_item_id      uuid,                   -- foreign key added below (needs portfolio_items)
  visibility         text not null default 'public'
                     check (visibility in ('public', 'unlisted', 'private')),
  status             text not null default 'pending_review'
                     check (status in ('pending_review', 'active', 'rejected',
                                       'taken_down', 'pending_appeal', 'denied_appeal')),
  rejection_reason   text check (char_length(rejection_reason) <= 1000),
  has_pending_media  boolean not null default false,
  reviewed_by        uuid references public.profiles (id) on delete set null,
  reviewed_at        timestamptz,
  upload_year        int not null default extract(year from now())::int,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index portfolios_user_id_idx on public.portfolios (user_id);
create index portfolios_status_visibility_idx on public.portfolios (status, visibility);


-- -----------------------------------------------------------------------------
-- portfolio_items: images, loops and video links inside a portfolio
-- -----------------------------------------------------------------------------
create table public.portfolio_items (
  id                uuid primary key default gen_random_uuid(),
  portfolio_id      uuid not null references public.portfolios (id) on delete cascade,
  type              text not null check (type in ('image', 'loop', 'video_embed')),
  -- image/loop: base storage key; sizes are derived (_480, _1280, _full)
  storage_key       text,
  embed_provider    text check (embed_provider in ('youtube', 'vimeo')),
  embed_id          text check (char_length(embed_id) <= 64),
  width             int check (width > 0),
  height            int check (height > 0),
  bytes             bigint not null default 0 check (bytes >= 0),
  position          int not null default 0,
  review_state      text not null default 'pending'
                    check (review_state in ('pending', 'live', 'rejected')),
  -- set when this item is a replacement for a live item (brief 4.3)
  replaces_item_id  uuid references public.portfolio_items (id) on delete set null,
  created_at        timestamptz not null default now(),

  -- Files need a storage key; video links need a provider and an id.
  constraint portfolio_items_kind_fields check (
    (type in ('image', 'loop') and storage_key is not null
                               and embed_provider is null and embed_id is null)
    or
    (type = 'video_embed' and storage_key is null
                          and embed_provider is not null and embed_id is not null)
  )
);

create index portfolio_items_portfolio_id_idx on public.portfolio_items (portfolio_id);

-- Now that portfolio_items exists, link the cover. Deleting the item clears the cover.
alter table public.portfolios
  add constraint portfolios_cover_item_id_fkey
  foreign key (cover_item_id) references public.portfolio_items (id) on delete set null;


-- -----------------------------------------------------------------------------
-- tags and portfolio_tags: the fixed tag list and which portfolio uses which
-- -----------------------------------------------------------------------------
create table public.tags (
  id    uuid primary key default gen_random_uuid(),
  name  text not null unique check (char_length(name) between 1 and 40)
);

create table public.portfolio_tags (
  portfolio_id  uuid not null references public.portfolios (id) on delete cascade,
  tag_id        uuid not null references public.tags (id) on delete cascade,
  primary key (portfolio_id, tag_id)
);

create index portfolio_tags_tag_id_idx on public.portfolio_tags (tag_id);


-- -----------------------------------------------------------------------------
-- portfolio_credits: collaborators on a group project (brief 4.7)
-- -----------------------------------------------------------------------------
create table public.portfolio_credits (
  id             uuid primary key default gen_random_uuid(),
  portfolio_id   uuid not null references public.portfolios (id) on delete cascade,
  profile_id     uuid references public.profiles (id) on delete cascade,  -- student on the platform
  external_name  text check (char_length(external_name) <= 120),          -- someone not on the platform
  role           text not null check (char_length(role) between 1 and 60),
  status         text not null default 'invited'
                 check (status in ('invited', 'accepted', 'declined')),
  created_at     timestamptz not null default now(),

  check (profile_id is not null or external_name is not null),
  -- External names cannot accept an invite, so they are always 'accepted'.
  check (profile_id is not null or status = 'accepted'),
  unique (portfolio_id, profile_id)
);

create index portfolio_credits_profile_id_idx on public.portfolio_credits (profile_id);


-- -----------------------------------------------------------------------------
-- likes and comments
-- -----------------------------------------------------------------------------
create table public.likes (
  user_id       uuid not null references public.profiles (id) on delete cascade,
  portfolio_id  uuid not null references public.portfolios (id) on delete cascade,
  created_at    timestamptz not null default now(),
  primary key (user_id, portfolio_id)        -- one like per user per portfolio
);

create index likes_portfolio_id_idx on public.likes (portfolio_id);

create table public.comments (
  id            uuid primary key default gen_random_uuid(),
  portfolio_id  uuid not null references public.portfolios (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  content       text not null check (char_length(content) between 1 and 1000),
  hidden        boolean not null default false,  -- set by the auto-hide trigger or moderators
  created_at    timestamptz not null default now()
);

create index comments_portfolio_id_idx on public.comments (portfolio_id);
create index comments_user_id_idx on public.comments (user_id);


-- -----------------------------------------------------------------------------
-- reports: a user flags a portfolio or a comment
-- -----------------------------------------------------------------------------
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references public.profiles (id) on delete cascade,
  portfolio_id  uuid references public.portfolios (id) on delete cascade,
  comment_id    uuid references public.comments (id) on delete cascade,
  category      text not null
                check (category in ('inappropriate', 'copyright', 'harassment', 'other')),
  details       text check (char_length(details) <= 1000),
  status        text not null default 'pending'
                check (status in ('pending', 'reviewed', 'actioned', 'dismissed')),
  created_at    timestamptz not null default now(),

  -- exactly one target
  check (num_nonnulls(portfolio_id, comment_id) = 1),
  -- a user can report the same thing only once
  unique (reporter_id, comment_id),
  unique (reporter_id, portfolio_id)
);

create index reports_comment_id_idx on public.reports (comment_id);
create index reports_portfolio_id_idx on public.reports (portfolio_id);


-- -----------------------------------------------------------------------------
-- warnings and takedowns: post-publication moderation (kept from the demo)
-- -----------------------------------------------------------------------------
create table public.warnings (
  id                 uuid primary key default gen_random_uuid(),
  portfolio_id       uuid not null references public.portfolios (id) on delete cascade,
  reason             text not null check (char_length(reason) between 1 and 1000),
  duration_days      int not null check (duration_days in (3, 7, 14)),
  expires_at         timestamptz not null,
  counter_statement  text check (char_length(counter_statement) <= 1000),
  resolved_at        timestamptz,
  created_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now()
);

create index warnings_portfolio_id_idx on public.warnings (portfolio_id);

create table public.takedowns (
  id                 uuid primary key default gen_random_uuid(),
  portfolio_id       uuid not null references public.portfolios (id) on delete cascade,
  reason             text not null check (char_length(reason) between 1 and 1000),
  -- The portfolio's status just before the takedown. An approved appeal puts
  -- it back exactly as it was (so unreviewed work never goes live).
  status_before      text not null
                     check (status_before in ('pending_review', 'active', 'rejected')),
  appeal_message     text check (char_length(appeal_message) <= 2000),
  appeal_status      text not null default 'none'
                     check (appeal_status in ('none', 'pending', 'approved', 'denied')),
  appeal_denied_at   timestamptz,
  scheduled_wipe_at  timestamptz,            -- 1 year after a denied appeal
  resolved_at        timestamptz,
  created_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now()
);

create index takedowns_portfolio_id_idx on public.takedowns (portfolio_id);


-- -----------------------------------------------------------------------------
-- audit_log: every moderation decision (written only by moderation functions)
-- -----------------------------------------------------------------------------
create table public.audit_log (
  id           uuid primary key default gen_random_uuid(),
  -- kept when the actor's account is deleted, so the history stays
  actor_id     uuid references public.profiles (id) on delete set null,
  action       text not null,
  target_type  text not null,
  target_id    uuid,
  details      jsonb,
  created_at   timestamptz not null default now()
);

create index audit_log_target_idx on public.audit_log (target_type, target_id);


-- -----------------------------------------------------------------------------
-- Row Level Security is ON for every table. With no policies, nobody except the
-- table owner (and the service role) can read or write. Policies are added in *_rls.sql.
-- -----------------------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.staff_invites     enable row level security;
alter table public.portfolios        enable row level security;
alter table public.portfolio_items   enable row level security;
alter table public.tags              enable row level security;
alter table public.portfolio_tags    enable row level security;
alter table public.portfolio_credits enable row level security;
alter table public.likes             enable row level security;
alter table public.comments          enable row level security;
alter table public.reports           enable row level security;
alter table public.warnings          enable row level security;
alter table public.takedowns         enable row level security;
alter table public.audit_log         enable row level security;
