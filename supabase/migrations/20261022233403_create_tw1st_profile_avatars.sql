/*
# Create TW1ST profile avatar storage

1. Storage
- Adds the `profile-avatars` bucket for profile pictures.
- Profile pictures are intentionally public because they are displayed beside usernames in shared chat rooms.

2. Security
- Signed-in users can upload, replace, and remove files only inside their own user-ID folder.
- Public read access is limited to this profile-picture bucket through the bucket's public setting.
- File paths must begin with the authenticated user's ID, preventing one account from writing into another account's folder.

3. Important Notes
- The application uses generated object names instead of trusting uploaded filenames.
- Existing profile records and application data are not modified.
*/

INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-avatars', 'profile-avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "profile_avatars_insert_own" ON storage.objects;
CREATE POLICY "profile_avatars_insert_own" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "profile_avatars_update_own" ON storage.objects;
CREATE POLICY "profile_avatars_update_own" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "profile_avatars_delete_own" ON storage.objects;
CREATE POLICY "profile_avatars_delete_own" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'profile-avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);