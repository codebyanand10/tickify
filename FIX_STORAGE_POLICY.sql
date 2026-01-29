-- ⚠️ CRITICAL SCRIPT TO FIX FILE UPLOAD ERROR ⚠️

-- The error "new row violates row level security policy" happens because
-- you are using Firebase Auth, but Supabase doesn't know about it.
-- Supabase thinks all your users are "Guests" (Anonymous).
-- We need to allow "Guests" to upload files to the 'certificates' bucket.

-- COPY AND PASTE THE FOLLOWING INTO SUPABASE SQL EDITOR:

-- 1. Enable Public Uploads to 'certificates' bucket
create policy "Allow Public Uploads"
on storage.objects for insert
to public
with check ( bucket_id = 'certificates' );

-- 2. Allow Public Updates (so they can replace their own files - strictly simplistic)
create policy "Allow Public Updates"
on storage.objects for update
to public
using ( bucket_id = 'certificates' );

-- 3. Ensure Public Read Access (so images can be seen)
create policy "Allow Public Reads"
on storage.objects for select
to public
using ( bucket_id = 'certificates' );

-- NOTES:
-- This makes the bucket publicly writable. For a student project, this is fine
-- and is the standard workaround for "Hybrid" (Firebase + Supabase) apps.
