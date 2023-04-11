CREATE TRIGGER before_delete_user BEFORE DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION delete_old_profile();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();


drop function if exists "public"."get_group_info"(current_group_id bigint, current_user_id uuid);

alter table "public"."profiles" add constraint "check_username" CHECK (((username IS NULL) OR (username ~ '^[a-z0-9._]+$'::text))) not valid;

alter table "public"."profiles" validate constraint "check_username";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_group_info_test(current_group_id bigint, current_user_id uuid)
 RETURNS TABLE(group_info jsonb, members jsonb, friends_not_in_group jsonb, events jsonb)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT 
    (SELECT jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name, 'description', g.description, 'created_at', g.created_at,
    'creator_username', p.username, 'creator_full_name', p.full_name, 'creator_avatar_url', p.avatar_url))
    FROM groups g
    INNER JOIN profiles p ON creator_id = p.id
    WHERE g.id = current_group_id),

    (SELECT jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'full_name', p.full_name, 'avatar_url', p.avatar_url))
    FROM members m
    INNER JOIN profiles p ON m.user_id = p.id
    WHERE m.group_id = current_group_id),
  
    (SELECT jsonb_agg(jsonb_build_object('id', f.friend_id, 'username', p.username, 'full_name', p.full_name, 'avatar_url', p.avatar_url))
    FROM friends f
    INNER JOIN profiles p ON f.friend_id = p.id
    WHERE f.user_id = current_user_id AND f.friend_id NOT IN (SELECT user_id FROM members WHERE group_id = current_group_id)),

    (SELECT jsonb_agg(jsonb_build_object('id', e.id, 'name', e.name, 'description', e.description, 'start', e.start, 'creator_full_name', p.full_name, 'creator_avatar_url', p.avatar_url, 'creator_username', p.username))
    FROM events e
    INNER JOIN profiles p ON e.creator_id = p.id
    WHERE e.group_id = current_group_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_group_info(current_group_id bigint, current_user_id uuid)
 RETURNS TABLE(group_info jsonb, members jsonb, friends_not_in_group jsonb, events jsonb)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT 
    (SELECT jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name, 'description', g.description, 'created_at', g.created_at,
    'creator_username', p.username, 'creator_full_name', p.full_name, 'creator_avatar_url', p.avatar_url))
    FROM groups g
    INNER JOIN profiles p ON creator_id = p.id
    WHERE g.id = current_group_id),

    (SELECT jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'full_name', p.full_name, 'avatar_url', p.avatar_url))
    FROM members m
    INNER JOIN profiles p ON m.user_id = p.id
    WHERE m.group_id = current_group_id),
  
    (SELECT jsonb_agg(jsonb_build_object('id', f.friend_id, 'username', p.username, 'full_name', p.full_name, 'avatar_url', p.avatar_url))
    FROM friends f
    INNER JOIN profiles p ON f.friend_id = p.id
    WHERE f.user_id = current_user_id AND f.friend_id NOT IN (SELECT user_id FROM members WHERE group_id = current_group_id)),

    (SELECT jsonb_agg(jsonb_build_object('id', e.id, 'name', e.name, 'description', e.description, 'start', e.start, 'creator_full_name', p.full_name, 'creator_avatar_url', p.avatar_url, 'creator_username', p.username))
    FROM events e
    INNER JOIN profiles p ON e.creator_id = p.id
    WHERE e.group_id = current_group_id);
END;
$function$
;

create policy "Enable delete for users based on user_id"
on "public"."members"
as permissive
for delete
to public
using ((auth.uid() = user_id));



alter table "storage"."objects" add column "version" text;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$function$
;

create policy "Anyone can upload an avatar."
on "storage"."objects"
as permissive
for insert
to authenticated
with check ((bucket_id = 'avatars'::text));


create policy "Avatar images are publicly accessible."
on "storage"."objects"
as permissive
for select
to public
using ((bucket_id = 'avatars'::text));



