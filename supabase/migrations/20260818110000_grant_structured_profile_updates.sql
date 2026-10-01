grant update (
  full_name,
  first_name,
  last_name,
  middle_initial,
  role_id,
  is_active,
  profile_image_path,
  updated_at
) on public.profiles to authenticated;
