-- Bucket público para fotos de perfil (Storage → avatars).
-- Compatível com Firebase third-party auth (claim JWT "sub" = Firebase UID).
--
-- Execute no SQL Editor do Supabase APÓS 002_firebase_third_party.sql.

-- ---------------------------------------------------------------------------
-- Bucket
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Políticas (storage.objects)
-- Caminho no app: {firebase_uid}/avatar.jpg
-- ---------------------------------------------------------------------------
drop policy if exists "avatars_select_public" on storage.objects;
drop policy if exists "avatars_insert_own" on storage.objects;
drop policy if exists "avatars_update_own" on storage.objects;
drop policy if exists "avatars_delete_own" on storage.objects;

-- Leitura pública (URL pública no ProfileAvatar / UserDock)
create policy "avatars_select_public"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Upload / substituição só na própria pasta
create policy "avatars_insert_own"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.jwt() ->> 'sub' = (storage.foldername(name))[1]
  );

create policy "avatars_update_own"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.jwt() ->> 'sub' = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'avatars'
    and auth.jwt() ->> 'sub' = (storage.foldername(name))[1]
  );

create policy "avatars_delete_own"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.jwt() ->> 'sub' = (storage.foldername(name))[1]
  );
