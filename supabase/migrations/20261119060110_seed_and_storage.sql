-- =============================================================================
-- Seed data and storage buckets
-- =============================================================================
--   1. The five fixed tags (brief 4.5). Only admins add more later.
--   2. Two storage buckets (brief 4.4):
--        media-private : pending work. NOT public. Read only through short-lived
--                        signed URLs, by the owner and by moderators.
--        media-public  : approved work only. Public URLs.
--      Unapproved work is never at a public URL.
--
-- Writes to both buckets come ONLY from server code (signed upload URLs created
-- after the server checks login, file type, size and quota, and copies on
-- approval). That is why there are no insert/update/delete policies below:
-- with RLS on storage.objects, no policy means browsers cannot write.
--
-- File layout in media-private: "<owner user id>/<anything>", for example
-- "3f1c.../portfolio-id/item-id_1280.webp". The first folder is the owner's id;
-- the read policy below depends on it.
--
-- Checked against the Supabase docs (Nov 2026): storage policies are ordinary
-- RLS policies on storage.objects; storage.foldername(name) splits the path.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Fixed tags
-- -----------------------------------------------------------------------------
insert into public.tags (name) values
  ('3D Modelling'),
  ('Character Design'),
  ('Graphic Design'),
  ('Illustration'),
  ('Video Editing')
on conflict (name) do nothing;


-- -----------------------------------------------------------------------------
-- 2. Buckets
-- -----------------------------------------------------------------------------
-- Limits match the media rules: WebP images (compressed in the browser) and
-- MP4 loops of at most 15 MB. Full videos are YouTube/Vimeo links, never files.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('media-private', 'media-private', false, 15728640, array['image/webp', 'video/mp4']),
  ('media-public',  'media-public',  true,  15728640, array['image/webp', 'video/mp4'])
on conflict (id) do nothing;


-- -----------------------------------------------------------------------------
-- 3. Storage policies
-- -----------------------------------------------------------------------------

-- media-private: a signed-in user may read files in their own folder
-- ("<their user id>/..."), so they can preview their pending work.
create policy "Owners read their own private media"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'media-private'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- media-private: moderators may read every pending file to review it.
create policy "Moderators read all private media"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'media-private'
    and (select public.is_moderator())
  );

-- media-public: no policy is needed for reading. A public bucket serves its
-- files to everyone by URL. Not adding a select policy also means nobody can
-- LIST the bucket's contents through the API.

-- No insert / update / delete policies on either bucket: only server code
-- (service role, which bypasses RLS) writes files.
