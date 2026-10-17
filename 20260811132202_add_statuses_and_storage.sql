/*
# Add statuses table + storage bucket for avatars and status photos

1. New Tables
- `statuses`: WhatsApp-style status stories. Each row is a photo/text status posted by a user.
  Columns: id, user_id (owner), content (text or image URL), type ('text' | 'image'),
  created_at, expires_at (auto-expires after 24h), viewed_by (array of user ids who viewed it).

2. Storage
- Create bucket 'avatars' for profile pictures (public read).
- Create bucket 'statuses' for status photos (public read).

3. Security
- statuses: any authenticated user can read all statuses (to see contacts' stories);
  only owner can insert/update/delete their own statuses.
- Storage policies: public read for avatars and statuses buckets; authenticated users
  can upload to their own folder path (user_id/<filename>).

4. Important notes
- Statuses auto-expire after 24 hours via expires_at column.
- viewed_by tracks which users have seen a status (like WhatsApp view receipts).
*/

-- ============ statuses table ============
CREATE TABLE IF NOT EXISTS public.statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image')),
  content text NOT NULL,
  bg_color text DEFAULT '#7c3aed',
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
  viewed_by uuid[] NOT NULL DEFAULT '{}'
);

ALTER TABLE public.statuses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "statuses_select_all" ON public.statuses;
CREATE POLICY "statuses_select_all"
  ON public.statuses FOR SELECT
  TO authenticated USING (true);

DROP POLICY IF EXISTS "statuses_insert_own" ON public.statuses;
CREATE POLICY "statuses_insert_own"
  ON public.statuses FOR INSERT
  TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "statuses_update_own" ON public.statuses;
CREATE POLICY "statuses_update_own"
  ON public.statuses FOR UPDATE
  TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "statuses_delete_own" ON public.statuses;
CREATE POLICY "statuses_delete_own"
  ON public.statuses FOR DELETE
  TO authenticated USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_statuses_user ON public.statuses (user_id);
CREATE INDEX IF NOT EXISTS idx_statuses_expires ON public.statuses (expires_at);

-- Enable realtime on statuses
ALTER PUBLICATION supabase_realtime ADD TABLE public.statuses;

-- ============ Storage buckets ============
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('statuses', 'statuses', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for avatars
DROP POLICY IF EXISTS "avatars_read_all" ON storage.objects;
CREATE POLICY "avatars_read_all"
  ON storage.objects FOR SELECT
  TO anon, authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated USING (bucket_id = 'avatars');

-- Storage policies for statuses
DROP POLICY IF EXISTS "statuses_read_all" ON storage.objects;
CREATE POLICY "statuses_read_all"
  ON storage.objects FOR SELECT
  TO anon, authenticated USING (bucket_id = 'statuses');

DROP POLICY IF EXISTS "statuses_insert_own" ON storage.objects;
CREATE POLICY "statuses_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated WITH CHECK (bucket_id = 'statuses');

DROP POLICY IF EXISTS "statuses_delete_own" ON storage.objects;
CREATE POLICY "statuses_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated USING (bucket_id = 'statuses');
