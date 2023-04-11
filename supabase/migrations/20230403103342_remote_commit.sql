--
-- PostgreSQL database dump
--

-- Dumped from database version 15.1
-- Dumped by pg_dump version 15.1 (Debian 15.1-1.pgdg110+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgsodium; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";


--
-- Name: http; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "http" WITH SCHEMA "extensions";


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";


--
-- Name: pgjwt; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";


--
-- Name: accept_invitation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."accept_invitation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    INSERT INTO members (user_id, group_id)
    VALUES (NEW.invitee_id, NEW.group_id);
    DELETE FROM invitations
      WHERE id = NEW.id;

  ELSIF NEW.status = 'rejected' THEN
    DELETE FROM invitations
      WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."accept_invitation"() OWNER TO "postgres";

--
-- Name: add_participation_on_event_create(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."add_participation_on_event_create"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO participations (event_id, user_id, status)
  VALUES (NEW.id, NEW.creator_id, 'yes');
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."add_participation_on_event_create"() OWNER TO "postgres";

--
-- Name: check_duplicate_invitation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."check_duplicate_invitation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM invitations 
        WHERE inviter_id = NEW.inviter_id 
          AND invitee_id = NEW.invitee_id
    ) THEN
        return null;
    END IF;
    RETURN NEW;
END; 
$$;


ALTER FUNCTION "public"."check_duplicate_invitation"() OWNER TO "postgres";

--
-- Name: check_friendship_limit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."check_friendship_limit"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  friend_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO friend_count
  FROM friends
  WHERE user_id = NEW.user_id OR friend_id = NEW.user_id;
  
  IF friend_count >= 1000 THEN
    RAISE EXCEPTION 'Friend limit reached';
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_friendship_limit"() OWNER TO "postgres";

--
-- Name: delete_avatar("text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."delete_avatar"("avatar_url" "text", OUT "status" integer, OUT "content" "text") RETURNS "record"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  select
      into status, content
           result.status, result.content
      from public.delete_storage_object('avatars', avatar_url) as result;
end;
$$;


ALTER FUNCTION "public"."delete_avatar"("avatar_url" "text", OUT "status" integer, OUT "content" "text") OWNER TO "postgres";

--
-- Name: delete_friend(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."delete_friend"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete the corresponding row from the friends table
  DELETE FROM friends
  WHERE user_id = OLD.friend_id AND friend_id = OLD.user_id;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."delete_friend"() OWNER TO "postgres";

--
-- Name: delete_old_avatar(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."delete_old_avatar"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  status int;
  content text;
begin
  if coalesce(old.avatar_url, '') <> ''
      and (tg_op = 'DELETE' or (old.avatar_url <> new.avatar_url)) then
    select
      into status, content
      result.status, result.content
      from public.delete_avatar(old.avatar_url) as result;
    if status <> 200 then
      raise warning 'Could not delete avatar: % %', status, content;
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."delete_old_avatar"() OWNER TO "postgres";

--
-- Name: delete_old_events_func(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."delete_old_events_func"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  delete from events where end_time < now();
  return new;
end;
$$;


ALTER FUNCTION "public"."delete_old_events_func"() OWNER TO "postgres";

--
-- Name: delete_old_profile(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."delete_old_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  delete from public.profiles where id = old.id;
  return old;
end;
$$;


ALTER FUNCTION "public"."delete_old_profile"() OWNER TO "postgres";

--
-- Name: delete_storage_object("text", "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."delete_storage_object"("bucket" "text", "object" "text", OUT "status" integer, OUT "content" "text") RETURNS "record"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  project_url text := 'https://bkdpqmkpqehtijnjqtlj.supabase.co';
  service_role_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJrZHBxbWtwcWVodGlqbmpxdGxqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTY3OTA3MDcxOCwiZXhwIjoxOTk0NjQ2NzE4fQ.7ALBuYE0VUjurUqf8Cy-WfLSSovzJtng1wIwkpbuUy8'; --  full access needed
  url text := project_url||'/storage/v1/object/'||bucket||'/'||object;
begin
  select
      into status, content
           result.status::int, result.content::text
      FROM extensions.http((
    'DELETE',
    url,
    ARRAY[extensions.http_header('authorization','Bearer '||service_role_key)],
    NULL,
    NULL)::extensions.http_request) as result;
end;
$$;


ALTER FUNCTION "public"."delete_storage_object"("bucket" "text", "object" "text", OUT "status" integer, OUT "content" "text") OWNER TO "postgres";

--
-- Name: get_friend_requests("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_friend_requests"("session_user_id" "uuid") RETURNS TABLE("request_id" bigint, "sender_profile" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT
    public.friend_requests.id,
    jsonb_build_object(
      'id', public.profiles.id,
      'username', public.profiles.username,
      'full_name', public.profiles.full_name,
      'num_friends', public.profiles.num_friends
    )
  FROM
    public.friend_requests
    INNER JOIN public.profiles ON public.friend_requests.user_id = public.profiles.id
  WHERE
    public.friend_requests.friend_id = session_user_id;
END;
$$;


ALTER FUNCTION "public"."get_friend_requests"("session_user_id" "uuid") OWNER TO "postgres";

--
-- Name: get_group_info(bigint, "uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_group_info"("current_group_id" bigint, "current_user_id" "uuid") RETURNS TABLE("friends_in_group" "jsonb", "friends_not_in_group" "jsonb", "events" "jsonb")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY SELECT 
    (SELECT jsonb_agg(jsonb_build_object('id', f.friend_id, 'username', p.username, 'full_name', p.full_name, 'avatar_url', p.avatar_url))
    FROM friends f
    INNER JOIN profiles p ON f.friend_id = p.id
    INNER JOIN members m ON f.friend_id = m.user_id
    WHERE m.group_id = current_group_id AND f.user_id = current_user_id),
  
    (SELECT jsonb_agg(jsonb_build_object('id', f.friend_id, 'username', p.username, 'full_name', p.full_name, 'avatar_url', p.avatar_url))
    FROM friends f
    INNER JOIN profiles p ON f.friend_id = p.id
    WHERE f.user_id = current_user_id AND f.friend_id NOT IN (SELECT user_id FROM members WHERE group_id = current_group_id)),

    (SELECT jsonb_agg(jsonb_build_object('id', e.id, 'name', e.name, 'description', e.description, 'start', e.start, 'creator_full_name', p.full_name, 'creator_avatar_url', p.avatar_url, 'creator_username', p.username))
    FROM events e
    INNER JOIN profiles p ON e.creator_id = p.id
    WHERE e.group_id = current_group_id);
END;
$$;


ALTER FUNCTION "public"."get_group_info"("current_group_id" bigint, "current_user_id" "uuid") OWNER TO "postgres";

--
-- Name: get_user_events("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_user_events"("current_user_id" "uuid") RETURNS TABLE("id" bigint, "group_id" bigint, "group_name" "text", "name" "text", "description" "text", "start" timestamp with time zone, "creator_full_name" "text", "creator_avatar_url" "text", "creator_username" "text", "participants" "jsonb"[])
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id, 
    e.group_id,
    g.name AS group_name,
    e.name,
    e.description,
    e.start,
    p.full_name AS creator_full_name, 
    p.avatar_url AS creator_avatar_url, 
    p.username AS creator_username,
    ARRAY(
      SELECT jsonb_build_object(
        'id', pr.id,
        'username', pr.username,
        'full_name', pr.full_name,
        'avatar_url', pr.avatar_url,
        'status', pa.status
      )
      FROM participations pa
      JOIN profiles pr ON pa.user_id = pr.id
      WHERE pa.event_id = e.id
    ) AS participants
  FROM events e
  INNER JOIN groups g ON g.id = e.group_id
  INNER JOIN profiles p ON e.creator_id = p.id
  WHERE e.start > now() AND g.id IN (
    SELECT m.group_id
    FROM members m
    WHERE m.user_id = current_user_id
  )
  ORDER BY e.start ASC;
END;
$$;


ALTER FUNCTION "public"."get_user_events"("current_user_id" "uuid") OWNER TO "postgres";

--
-- Name: get_user_events_with_group_info("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_user_events_with_group_info"("current_user_id" "uuid") RETURNS TABLE("id" bigint, "group_id" bigint, "group_name" "text", "name" "text", "description" "text", "start" timestamp with time zone, "creator_full_name" "text", "creator_avatar_url" "text", "creator_username" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id, 
    e.group_id,
    g.name AS group_name,
    e.name,
    e.description,
    e.start,
    p.full_name AS creator_full_name, 
    p.avatar_url AS creator_avatar_url, 
    p.username AS creator_username
  FROM events e
  INNER JOIN groups g ON g.id = e.group_id
  INNER JOIN profiles p ON e.creator_id = p.id
  INNER JOIN members m ON m.group_id = g.id
  WHERE m.user_id = current_user_id AND e.start > now()
  ORDER BY e.start ASC;
END;
$$;


ALTER FUNCTION "public"."get_user_events_with_group_info"("current_user_id" "uuid") OWNER TO "postgres";

--
-- Name: get_user_events_with_participants_and_non_participants("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_user_events_with_participants_and_non_participants"("current_user_id" "uuid") RETURNS TABLE("id" bigint, "group_id" bigint, "group_name" "text", "name" "text", "description" "text", "start" timestamp with time zone, "creator_full_name" "text", "creator_avatar_url" "text", "creator_username" "text", "participants" "json"[], "non_participants" "json"[])
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id, 
    e.group_id,
    g.name AS group_name,
    e.name,
    e.description,
    e.start,
    p.full_name AS creator_full_name, 
    p.avatar_url AS creator_avatar_url, 
    p.username AS creator_username,
    ARRAY(
      SELECT json_build_object(
        'id', pr.id,
        'username', pr.username,
        'full_name', pr.full_name,
        'avatar_url', pr.avatar_url
      )
      FROM participations pa
      JOIN profiles pr ON pa.user_id = pr.id
      WHERE pa.event_id = e.id AND pa.status = 'yes'
    ) AS participants,
    ARRAY(
      SELECT json_build_object(
        'id', pr.id,
        'username', pr.username,
        'full_name', pr.full_name,
        'avatar_url', pr.avatar_url
      )
      FROM profiles pr
      WHERE pr.id IN (
        SELECT m.user_id
        FROM members m
        WHERE m.group_id = e.group_id AND m.user_id != current_user_id
      ) AND pr.id NOT IN (
        SELECT pa.user_id
        FROM participations pa
        WHERE pa.event_id = e.id AND pa.status IN ('yes', 'maybe')
      )
    ) AS non_participants
  FROM events e
  INNER JOIN groups g ON g.id = e.group_id
  INNER JOIN profiles p ON e.creator_id = p.id
  WHERE e.start > now() AND g.id IN (
    SELECT m.group_id
    FROM members m
    WHERE m.user_id = current_user_id
  )
  ORDER BY e.start ASC;
END;
$$;


ALTER FUNCTION "public"."get_user_events_with_participants_and_non_participants"("current_user_id" "uuid") OWNER TO "postgres";

--
-- Name: get_user_invitations_with_group_info("uuid"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_user_invitations_with_group_info"("current_user_id" "uuid") RETURNS TABLE("id" bigint, "group_id" bigint, "group_name" "text", "group_description" "text", "inviter_username" "text", "inviter_full_name" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    i.id, 
    g.id AS group_id, 
    g.name AS group_name, 
    g.description AS group_description, 
    p.username AS inviter_username, 
    p.full_name AS inviter_full_name
  FROM invitations i
  INNER JOIN groups g ON g.id = i.group_id
  INNER JOIN profiles p ON i.inviter_id = p.id
  LEFT JOIN members m ON m.group_id = g.id
  WHERE i.invitee_id = current_user_id
  GROUP BY i.id, g.id, g.description, p.username, p.full_name
  ORDER BY i.id DESC;
END;
$$;


ALTER FUNCTION "public"."get_user_invitations_with_group_info"("current_user_id" "uuid") OWNER TO "postgres";

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";

--
-- Name: insert_group_member(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."insert_group_member"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  insert into public.members (group_id, user_id, role)
  values (new.id, new.creator_id, 'admin');
  return new;
end;
$$;


ALTER FUNCTION "public"."insert_group_member"() OWNER TO "postgres";

--
-- Name: on_friend_request_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."on_friend_request_update"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  IF NEW.status = 'accepted' THEN
    -- insert 2 rows in the friends table
    insert into friends (user_id, friend_id)
      values (NEW.user_id, NEW.friend_id), (NEW.friend_id, NEW.user_id);
    -- Delete the accepted friend request
    delete from friend_requests where id = NEW.id;
  ELSIF NEW.status = 'rejected' THEN
    delete from friend_requests where id = NEW.id;
  END IF;

  -- Return the new row in the friends table
  RETURN NEW;
end;
$$;


ALTER FUNCTION "public"."on_friend_request_update"() OWNER TO "postgres";

--
-- Name: update_num_friends(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."update_num_friends"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE profiles u
  SET num_friends = (SELECT COUNT(*) FROM friends WHERE user_id = u.id)
  WHERE u.id = NEW.user_id 
  -- OR u.id = NEW.friend_id 
  OR u.id = OLD.user_id;
  -- OR u.id = OLD.friend_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_num_friends"() OWNER TO "postgres";

--
-- Name: update_num_groups(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."update_num_groups"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE profiles u
  SET num_groups = (SELECT COUNT(*) FROM members WHERE user_id = u.id)
  WHERE u.id = NEW.user_id OR u.id = OLD.user_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_num_groups"() OWNER TO "postgres";

--
-- Name: upsert_participation(bigint, "uuid", "text"); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."upsert_participation"("current_event_id" bigint, "current_user_id" "uuid", "current_status" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete existing participations with the same event_id and user_id
  DELETE FROM participations 
  WHERE event_id = current_event_id 
    AND user_id = current_user_id;
  
  -- Insert the new participation
  INSERT INTO participations (event_id, user_id, status) 
  VALUES (current_event_id, current_user_id, current_status);
END;
$$;


ALTER FUNCTION "public"."upsert_participation"("current_event_id" bigint, "current_user_id" "uuid", "current_status" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."groups" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "name" "text" NOT NULL,
    "description" "text" NOT NULL,
    "creator_id" "uuid" NOT NULL
);


ALTER TABLE "public"."groups" OWNER TO "postgres";

--
-- Name: Groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."groups" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Groups_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."members" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" NOT NULL,
    "group_id" bigint NOT NULL,
    "role" character varying DEFAULT ''::character varying
);


ALTER TABLE "public"."members" OWNER TO "postgres";

--
-- Name: Members_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."members" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."Members_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."events" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "creator_id" "uuid",
    "group_id" bigint,
    "name" "text",
    "description" "text",
    "start" timestamp with time zone
);


ALTER TABLE "public"."events" OWNER TO "postgres";

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."events" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: friend_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."friend_requests" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" NOT NULL,
    "friend_id" "uuid" NOT NULL,
    "status" "text"
);


ALTER TABLE "public"."friend_requests" OWNER TO "postgres";

--
-- Name: friend_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."friend_requests" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."friend_requests_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: friends; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."friends" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid" NOT NULL,
    "friend_id" "uuid" NOT NULL
);


ALTER TABLE "public"."friends" OWNER TO "postgres";

--
-- Name: friends_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."friends" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."friends_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."invitations" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "inviter_id" "uuid" NOT NULL,
    "invitee_id" "uuid" NOT NULL,
    "group_id" bigint NOT NULL,
    "status" "text" DEFAULT 'pending'::"text"
);


ALTER TABLE "public"."invitations" OWNER TO "postgres";

--
-- Name: invitations__id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."invitations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."invitations__id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: participations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."participations" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid",
    "event_id" bigint,
    "status" "text"
);


ALTER TABLE "public"."participations" OWNER TO "postgres";

--
-- Name: participations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."participations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."participations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."profiles" (
    "id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "website" "text",
    "num_groups" bigint DEFAULT '0'::bigint,
    "num_friends" bigint DEFAULT '0'::bigint,
    CONSTRAINT "check_username_length" CHECK (("length"("username") <= 20)),
    CONSTRAINT "max_num_groups" CHECK (("num_groups" <= 50)),
    CONSTRAINT "username_length" CHECK (("char_length"("username") >= 3))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";

--
-- Name: groups Groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "Groups_pkey" PRIMARY KEY ("id");


--
-- Name: members Members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "Members_pkey" PRIMARY KEY ("id");


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");


--
-- Name: friend_requests friend_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."friend_requests"
    ADD CONSTRAINT "friend_requests_pkey" PRIMARY KEY ("id");


--
-- Name: friends friends_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_pkey" PRIMARY KEY ("id");


--
-- Name: invitations invitations__pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations__pkey" PRIMARY KEY ("id");


--
-- Name: participations participations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."participations"
    ADD CONSTRAINT "participations_pkey" PRIMARY KEY ("id");


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");


--
-- Name: profiles profiles_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");


--
-- Name: invitations accept_invitation_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "accept_invitation_trigger" AFTER UPDATE OF "status" ON "public"."invitations" FOR EACH ROW EXECUTE FUNCTION "public"."accept_invitation"();


--
-- Name: groups add_creator_to_members; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "add_creator_to_members" AFTER INSERT ON "public"."groups" FOR EACH ROW EXECUTE FUNCTION "public"."insert_group_member"();


--
-- Name: profiles before_profile_changes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "before_profile_changes" BEFORE DELETE OR UPDATE OF "avatar_url" ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."delete_old_avatar"();


--
-- Name: invitations check_duplicate_invitation_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "check_duplicate_invitation_trigger" BEFORE INSERT ON "public"."invitations" FOR EACH ROW EXECUTE FUNCTION "public"."check_duplicate_invitation"();


--
-- Name: friends check_friendship_limit_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "check_friendship_limit_trigger" BEFORE INSERT ON "public"."friends" FOR EACH ROW EXECUTE FUNCTION "public"."check_friendship_limit"();


--
-- Name: friends delete_friend_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "delete_friend_trigger" AFTER DELETE ON "public"."friends" FOR EACH ROW EXECUTE FUNCTION "public"."delete_friend"();


--
-- Name: friend_requests friend_request_update_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "friend_request_update_trigger" AFTER UPDATE ON "public"."friend_requests" FOR EACH ROW EXECUTE FUNCTION "public"."on_friend_request_update"();


--
-- Name: events insert_participation_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "insert_participation_trigger" AFTER INSERT ON "public"."events" FOR EACH ROW EXECUTE FUNCTION "public"."add_participation_on_event_create"();


--
-- Name: friends update_num_friends_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "update_num_friends_trigger" AFTER INSERT OR DELETE ON "public"."friends" FOR EACH ROW EXECUTE FUNCTION "public"."update_num_friends"();


--
-- Name: members update_num_friends_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "update_num_friends_trigger" AFTER INSERT OR DELETE ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."update_num_friends"();


--
-- Name: members update_num_groups_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "update_num_groups_trigger" AFTER INSERT OR DELETE ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "public"."update_num_groups"();


--
-- Name: events events_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id");


--
-- Name: events events_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id");


--
-- Name: friend_requests friend_requests_friend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."friend_requests"
    ADD CONSTRAINT "friend_requests_friend_id_fkey" FOREIGN KEY ("friend_id") REFERENCES "public"."profiles"("id");


--
-- Name: friend_requests friend_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."friend_requests"
    ADD CONSTRAINT "friend_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");


--
-- Name: friends friends_friend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_friend_id_fkey" FOREIGN KEY ("friend_id") REFERENCES "public"."profiles"("id");


--
-- Name: friends friends_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."friends"
    ADD CONSTRAINT "friends_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");


--
-- Name: groups groups_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "auth"."users"("id");


--
-- Name: invitations invitations_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id");


--
-- Name: invitations invitations_invitee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_invitee_id_fkey" FOREIGN KEY ("invitee_id") REFERENCES "auth"."users"("id");


--
-- Name: invitations invitations_inviter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."invitations"
    ADD CONSTRAINT "invitations_inviter_id_fkey" FOREIGN KEY ("inviter_id") REFERENCES "auth"."users"("id");


--
-- Name: members members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id");


--
-- Name: members members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");


--
-- Name: participations participations_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."participations"
    ADD CONSTRAINT "participations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id");


--
-- Name: participations participations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."participations"
    ADD CONSTRAINT "participations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;


--
-- Name: friend_requests Enable delete for users based on friend_id; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for users based on friend_id" ON "public"."friend_requests" FOR DELETE USING ((( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("auth"."uid"() = "profiles"."id")) = "friend_id"));


--
-- Name: friends Enable delete for users based on user_id; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for users based on user_id" ON "public"."friends" FOR DELETE USING ((("auth"."uid"() = "user_id") OR ("auth"."uid"() = "friend_id")));


--
-- Name: invitations Enable delete for users based on user_id; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for users based on user_id" ON "public"."invitations" FOR DELETE TO "authenticated" USING ((( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("auth"."uid"() = "profiles"."id")) = "invitee_id"));


--
-- Name: participations Enable delete for users based on user_id; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable delete for users based on user_id" ON "public"."participations" FOR DELETE USING (("auth"."uid"() = "user_id"));


--
-- Name: events Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."events" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: friend_requests Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."friend_requests" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: friends Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."friends" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: groups Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."groups" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "count"(*) AS "count"
   FROM "public"."members"
  WHERE ("members"."user_id" = "auth"."uid"())) < 50));


--
-- Name: invitations Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."invitations" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: members Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."members" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "count"(*) AS "count"
   FROM "public"."members" "members_1"
  WHERE ("members_1"."user_id" = "auth"."uid"())) < 50));


--
-- Name: participations Enable insert for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable insert for authenticated users only" ON "public"."participations" FOR INSERT TO "authenticated" WITH CHECK (true);


--
-- Name: events Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON "public"."events" FOR SELECT TO "authenticated" USING (true);


--
-- Name: friends Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON "public"."friends" FOR SELECT USING (true);


--
-- Name: groups Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON "public"."groups" FOR SELECT USING (true);


--
-- Name: invitations Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON "public"."invitations" FOR SELECT USING (true);


--
-- Name: members Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON "public"."members" FOR SELECT USING (true);


--
-- Name: participations Enable read access for all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read access for all users" ON "public"."participations" FOR SELECT USING (true);


--
-- Name: friend_requests Enable read for authenticated users only; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable read for authenticated users only" ON "public"."friend_requests" FOR SELECT TO "authenticated" USING (true);


--
-- Name: participations Enable update for owner user; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for owner user" ON "public"."participations" FOR UPDATE USING (("auth"."uid"() = "user_id"));


--
-- Name: friend_requests Enable update for users based on email; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for users based on email" ON "public"."friend_requests" FOR UPDATE USING ((( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("auth"."uid"() = "profiles"."id")) = "friend_id")) WITH CHECK ((( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("auth"."uid"() = "profiles"."id")) = "friend_id"));


--
-- Name: invitations Enable update for users based on invitee_id; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Enable update for users based on invitee_id" ON "public"."invitations" FOR UPDATE USING ((( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("auth"."uid"() = "profiles"."id")) = "invitee_id")) WITH CHECK ((( SELECT "profiles"."id"
   FROM "public"."profiles"
  WHERE ("auth"."uid"() = "profiles"."id")) = "invitee_id"));


--
-- Name: profiles Public profiles are viewable by everyone.; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);


--
-- Name: profiles Users can insert their own profile.; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));


--
-- Name: profiles Users can update own profile.; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING ((("auth"."uid"() = "id") OR (( SELECT "friends"."user_id"
   FROM "public"."friends"
  WHERE ("friends"."friend_id" = "auth"."uid"())) = "id")));


--
-- Name: events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;

--
-- Name: friend_requests; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."friend_requests" ENABLE ROW LEVEL SECURITY;

--
-- Name: friends; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."friends" ENABLE ROW LEVEL SECURITY;

--
-- Name: groups; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."groups" ENABLE ROW LEVEL SECURITY;

--
-- Name: invitations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."invitations" ENABLE ROW LEVEL SECURITY;

--
-- Name: members; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."members" ENABLE ROW LEVEL SECURITY;

--
-- Name: participations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."participations" ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA "public"; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


--
-- Name: FUNCTION "algorithm_sign"("signables" "text", "secret" "text", "algorithm" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."algorithm_sign"("signables" "text", "secret" "text", "algorithm" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."algorithm_sign"("signables" "text", "secret" "text", "algorithm" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."algorithm_sign"("signables" "text", "secret" "text", "algorithm" "text") TO "dashboard_user";


--
-- Name: FUNCTION "armor"("bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."armor"("bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea") TO "dashboard_user";


--
-- Name: FUNCTION "armor"("bytea", "text"[], "text"[]); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."armor"("bytea", "text"[], "text"[]) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea", "text"[], "text"[]) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."armor"("bytea", "text"[], "text"[]) TO "dashboard_user";


--
-- Name: FUNCTION "crypt"("text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."crypt"("text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."crypt"("text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."crypt"("text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "dearmor"("text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."dearmor"("text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."dearmor"("text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."dearmor"("text") TO "dashboard_user";


--
-- Name: FUNCTION "decrypt"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."decrypt"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."decrypt"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."decrypt"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "decrypt_iv"("bytea", "bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."decrypt_iv"("bytea", "bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."decrypt_iv"("bytea", "bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."decrypt_iv"("bytea", "bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "digest"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."digest"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."digest"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."digest"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "digest"("text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."digest"("text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."digest"("text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."digest"("text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "encrypt"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."encrypt"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."encrypt"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."encrypt"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "encrypt_iv"("bytea", "bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."encrypt_iv"("bytea", "bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."encrypt_iv"("bytea", "bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."encrypt_iv"("bytea", "bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "gen_random_bytes"(integer); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_random_bytes"(integer) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_random_bytes"(integer) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_random_bytes"(integer) TO "dashboard_user";


--
-- Name: FUNCTION "gen_random_uuid"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_random_uuid"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_random_uuid"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_random_uuid"() TO "dashboard_user";


--
-- Name: FUNCTION "gen_salt"("text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_salt"("text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text") TO "dashboard_user";


--
-- Name: FUNCTION "gen_salt"("text", integer); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."gen_salt"("text", integer) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text", integer) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."gen_salt"("text", integer) TO "dashboard_user";


--
-- Name: FUNCTION "hmac"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."hmac"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."hmac"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."hmac"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "hmac"("text", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."hmac"("text", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."hmac"("text", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."hmac"("text", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "http"("request" "extensions"."http_request"); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http"("request" "extensions"."http_request") TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_delete"("uri" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_delete"("uri" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_delete"("uri" character varying, "content" character varying, "content_type" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_delete"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_get"("uri" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_get"("uri" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_get"("uri" character varying, "data" "jsonb"); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_get"("uri" character varying, "data" "jsonb") TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_head"("uri" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_head"("uri" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_header"("field" character varying, "value" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_header"("field" character varying, "value" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_list_curlopt"(); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_list_curlopt"() TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_patch"("uri" character varying, "content" character varying, "content_type" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_patch"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_post"("uri" character varying, "data" "jsonb"); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_post"("uri" character varying, "data" "jsonb") TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_post"("uri" character varying, "content" character varying, "content_type" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_post"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_put"("uri" character varying, "content" character varying, "content_type" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_put"("uri" character varying, "content" character varying, "content_type" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_reset_curlopt"(); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_reset_curlopt"() TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "http_set_curlopt"("curlopt" character varying, "value" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."http_set_curlopt"("curlopt" character varying, "value" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "blk_read_time" double precision, OUT "blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "blk_read_time" double precision, OUT "blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "blk_read_time" double precision, OUT "blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements"("showtext" boolean, OUT "userid" "oid", OUT "dbid" "oid", OUT "toplevel" boolean, OUT "queryid" bigint, OUT "query" "text", OUT "plans" bigint, OUT "total_plan_time" double precision, OUT "min_plan_time" double precision, OUT "max_plan_time" double precision, OUT "mean_plan_time" double precision, OUT "stddev_plan_time" double precision, OUT "calls" bigint, OUT "total_exec_time" double precision, OUT "min_exec_time" double precision, OUT "max_exec_time" double precision, OUT "mean_exec_time" double precision, OUT "stddev_exec_time" double precision, OUT "rows" bigint, OUT "shared_blks_hit" bigint, OUT "shared_blks_read" bigint, OUT "shared_blks_dirtied" bigint, OUT "shared_blks_written" bigint, OUT "local_blks_hit" bigint, OUT "local_blks_read" bigint, OUT "local_blks_dirtied" bigint, OUT "local_blks_written" bigint, OUT "temp_blks_read" bigint, OUT "temp_blks_written" bigint, OUT "blk_read_time" double precision, OUT "blk_write_time" double precision, OUT "temp_blk_read_time" double precision, OUT "temp_blk_write_time" double precision, OUT "wal_records" bigint, OUT "wal_fpi" bigint, OUT "wal_bytes" numeric, OUT "jit_functions" bigint, OUT "jit_generation_time" double precision, OUT "jit_inlining_count" bigint, OUT "jit_inlining_time" double precision, OUT "jit_optimization_count" bigint, OUT "jit_optimization_time" double precision, OUT "jit_emission_count" bigint, OUT "jit_emission_time" double precision) TO "dashboard_user";


--
-- Name: FUNCTION "pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_info"(OUT "dealloc" bigint, OUT "stats_reset" timestamp with time zone) TO "dashboard_user";


--
-- Name: FUNCTION "pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint) FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint) TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pg_stat_statements_reset"("userid" "oid", "dbid" "oid", "queryid" bigint) TO "dashboard_user";


--
-- Name: FUNCTION "pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_armor_headers"("text", OUT "key" "text", OUT "value" "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_key_id"("bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_key_id"("bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_key_id"("bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_key_id"("bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt"("bytea", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt"("bytea", "bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt"("bytea", "bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt_bytea"("bytea", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt_bytea"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_decrypt_bytea"("bytea", "bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt"("text", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt"("text", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt"("text", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt_bytea"("bytea", "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_pub_encrypt_bytea"("bytea", "bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_pub_encrypt_bytea"("bytea", "bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt"("bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt"("bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt_bytea"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_decrypt_bytea"("bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_decrypt_bytea"("bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt"("text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt"("text", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt"("text", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt_bytea"("bytea", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text") TO "dashboard_user";


--
-- Name: FUNCTION "pgp_sym_encrypt_bytea"("bytea", "text", "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text", "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text", "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."pgp_sym_encrypt_bytea"("bytea", "text", "text") TO "dashboard_user";


--
-- Name: FUNCTION "sign"("payload" "json", "secret" "text", "algorithm" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."sign"("payload" "json", "secret" "text", "algorithm" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."sign"("payload" "json", "secret" "text", "algorithm" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."sign"("payload" "json", "secret" "text", "algorithm" "text") TO "dashboard_user";


--
-- Name: FUNCTION "try_cast_double"("inp" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."try_cast_double"("inp" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."try_cast_double"("inp" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."try_cast_double"("inp" "text") TO "dashboard_user";


--
-- Name: FUNCTION "url_decode"("data" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."url_decode"("data" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."url_decode"("data" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."url_decode"("data" "text") TO "dashboard_user";


--
-- Name: FUNCTION "url_encode"("data" "bytea"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."url_encode"("data" "bytea") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."url_encode"("data" "bytea") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."url_encode"("data" "bytea") TO "dashboard_user";


--
-- Name: FUNCTION "urlencode"("string" "bytea"); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."urlencode"("string" "bytea") TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "urlencode"("data" "jsonb"); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."urlencode"("data" "jsonb") TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "urlencode"("string" character varying); Type: ACL; Schema: extensions; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "extensions"."urlencode"("string" character varying) TO "postgres" WITH GRANT OPTION;


--
-- Name: FUNCTION "uuid_generate_v1"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v1"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v1mc"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v1mc"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1mc"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v1mc"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v3"("namespace" "uuid", "name" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v3"("namespace" "uuid", "name" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v3"("namespace" "uuid", "name" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v3"("namespace" "uuid", "name" "text") TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v4"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v4"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v4"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v4"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_generate_v5"("namespace" "uuid", "name" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_generate_v5"("namespace" "uuid", "name" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_generate_v5"("namespace" "uuid", "name" "text") TO "dashboard_user";


--
-- Name: FUNCTION "uuid_nil"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_nil"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_nil"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_nil"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_dns"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_dns"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_dns"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_dns"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_oid"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_oid"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_oid"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_oid"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_url"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_url"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_url"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_url"() TO "dashboard_user";


--
-- Name: FUNCTION "uuid_ns_x500"(); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."uuid_ns_x500"() FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_x500"() TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."uuid_ns_x500"() TO "dashboard_user";


--
-- Name: FUNCTION "verify"("token" "text", "secret" "text", "algorithm" "text"); Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON FUNCTION "extensions"."verify"("token" "text", "secret" "text", "algorithm" "text") FROM "postgres";
-- GRANT ALL ON FUNCTION "extensions"."verify"("token" "text", "secret" "text", "algorithm" "text") TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON FUNCTION "extensions"."verify"("token" "text", "secret" "text", "algorithm" "text") TO "dashboard_user";


--
-- Name: FUNCTION "comment_directive"("comment_" "text"); Type: ACL; Schema: graphql; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "graphql"."comment_directive"("comment_" "text") TO "postgres";
-- GRANT ALL ON FUNCTION "graphql"."comment_directive"("comment_" "text") TO "anon";
-- GRANT ALL ON FUNCTION "graphql"."comment_directive"("comment_" "text") TO "authenticated";
-- GRANT ALL ON FUNCTION "graphql"."comment_directive"("comment_" "text") TO "service_role";


--
-- Name: FUNCTION "exception"("message" "text"); Type: ACL; Schema: graphql; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "graphql"."exception"("message" "text") TO "postgres";
-- GRANT ALL ON FUNCTION "graphql"."exception"("message" "text") TO "anon";
-- GRANT ALL ON FUNCTION "graphql"."exception"("message" "text") TO "authenticated";
-- GRANT ALL ON FUNCTION "graphql"."exception"("message" "text") TO "service_role";


--
-- Name: FUNCTION "get_schema_version"(); Type: ACL; Schema: graphql; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "graphql"."get_schema_version"() TO "postgres";
-- GRANT ALL ON FUNCTION "graphql"."get_schema_version"() TO "anon";
-- GRANT ALL ON FUNCTION "graphql"."get_schema_version"() TO "authenticated";
-- GRANT ALL ON FUNCTION "graphql"."get_schema_version"() TO "service_role";


--
-- Name: FUNCTION "increment_schema_version"(); Type: ACL; Schema: graphql; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "graphql"."increment_schema_version"() TO "postgres";
-- GRANT ALL ON FUNCTION "graphql"."increment_schema_version"() TO "anon";
-- GRANT ALL ON FUNCTION "graphql"."increment_schema_version"() TO "authenticated";
-- GRANT ALL ON FUNCTION "graphql"."increment_schema_version"() TO "service_role";


--
-- Name: FUNCTION "graphql"("operationName" "text", "query" "text", "variables" "jsonb", "extensions" "jsonb"); Type: ACL; Schema: graphql_public; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "graphql_public"."graphql"("operationName" "text", "query" "text", "variables" "jsonb", "extensions" "jsonb") TO "postgres";
-- GRANT ALL ON FUNCTION "graphql_public"."graphql"("operationName" "text", "query" "text", "variables" "jsonb", "extensions" "jsonb") TO "anon";
-- GRANT ALL ON FUNCTION "graphql_public"."graphql"("operationName" "text", "query" "text", "variables" "jsonb", "extensions" "jsonb") TO "authenticated";
-- GRANT ALL ON FUNCTION "graphql_public"."graphql"("operationName" "text", "query" "text", "variables" "jsonb", "extensions" "jsonb") TO "service_role";


--
-- Name: FUNCTION "crypto_aead_det_decrypt"("message" "bytea", "additional" "bytea", "key_uuid" "uuid", "nonce" "bytea"); Type: ACL; Schema: pgsodium; Owner: pgsodium_keymaker
--

-- GRANT ALL ON FUNCTION "pgsodium"."crypto_aead_det_decrypt"("message" "bytea", "additional" "bytea", "key_uuid" "uuid", "nonce" "bytea") TO "service_role";


--
-- Name: FUNCTION "crypto_aead_det_encrypt"("message" "bytea", "additional" "bytea", "key_uuid" "uuid", "nonce" "bytea"); Type: ACL; Schema: pgsodium; Owner: pgsodium_keymaker
--

-- GRANT ALL ON FUNCTION "pgsodium"."crypto_aead_det_encrypt"("message" "bytea", "additional" "bytea", "key_uuid" "uuid", "nonce" "bytea") TO "service_role";


--
-- Name: FUNCTION "crypto_aead_det_keygen"(); Type: ACL; Schema: pgsodium; Owner: supabase_admin
--

-- GRANT ALL ON FUNCTION "pgsodium"."crypto_aead_det_keygen"() TO "service_role";


--
-- Name: FUNCTION "accept_invitation"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."accept_invitation"() TO "anon";
GRANT ALL ON FUNCTION "public"."accept_invitation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_invitation"() TO "service_role";


--
-- Name: FUNCTION "add_participation_on_event_create"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."add_participation_on_event_create"() TO "anon";
GRANT ALL ON FUNCTION "public"."add_participation_on_event_create"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_participation_on_event_create"() TO "service_role";


--
-- Name: FUNCTION "check_duplicate_invitation"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."check_duplicate_invitation"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_duplicate_invitation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_duplicate_invitation"() TO "service_role";


--
-- Name: FUNCTION "check_friendship_limit"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."check_friendship_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_friendship_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_friendship_limit"() TO "service_role";


--
-- Name: FUNCTION "delete_avatar"("avatar_url" "text", OUT "status" integer, OUT "content" "text"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_avatar"("avatar_url" "text", OUT "status" integer, OUT "content" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_avatar"("avatar_url" "text", OUT "status" integer, OUT "content" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_avatar"("avatar_url" "text", OUT "status" integer, OUT "content" "text") TO "service_role";


--
-- Name: FUNCTION "delete_friend"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_friend"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_friend"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_friend"() TO "service_role";


--
-- Name: FUNCTION "delete_old_avatar"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_old_avatar"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_old_avatar"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_old_avatar"() TO "service_role";


--
-- Name: FUNCTION "delete_old_events_func"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_old_events_func"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_old_events_func"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_old_events_func"() TO "service_role";


--
-- Name: FUNCTION "delete_old_profile"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_old_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_old_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_old_profile"() TO "service_role";


--
-- Name: FUNCTION "delete_storage_object"("bucket" "text", "object" "text", OUT "status" integer, OUT "content" "text"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."delete_storage_object"("bucket" "text", "object" "text", OUT "status" integer, OUT "content" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_storage_object"("bucket" "text", "object" "text", OUT "status" integer, OUT "content" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_storage_object"("bucket" "text", "object" "text", OUT "status" integer, OUT "content" "text") TO "service_role";


--
-- Name: FUNCTION "get_friend_requests"("session_user_id" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_friend_requests"("session_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_friend_requests"("session_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_friend_requests"("session_user_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "get_group_info"("current_group_id" bigint, "current_user_id" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_group_info"("current_group_id" bigint, "current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_group_info"("current_group_id" bigint, "current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_group_info"("current_group_id" bigint, "current_user_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "get_user_events"("current_user_id" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_user_events"("current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_events"("current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_events"("current_user_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "get_user_events_with_group_info"("current_user_id" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_user_events_with_group_info"("current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_events_with_group_info"("current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_events_with_group_info"("current_user_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "get_user_events_with_participants_and_non_participants"("current_user_id" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_user_events_with_participants_and_non_participants"("current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_events_with_participants_and_non_participants"("current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_events_with_participants_and_non_participants"("current_user_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "get_user_invitations_with_group_info"("current_user_id" "uuid"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."get_user_invitations_with_group_info"("current_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_invitations_with_group_info"("current_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_invitations_with_group_info"("current_user_id" "uuid") TO "service_role";


--
-- Name: FUNCTION "handle_new_user"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";


--
-- Name: FUNCTION "insert_group_member"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."insert_group_member"() TO "anon";
GRANT ALL ON FUNCTION "public"."insert_group_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."insert_group_member"() TO "service_role";


--
-- Name: FUNCTION "on_friend_request_update"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."on_friend_request_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."on_friend_request_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."on_friend_request_update"() TO "service_role";


--
-- Name: FUNCTION "update_num_friends"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."update_num_friends"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_num_friends"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_num_friends"() TO "service_role";


--
-- Name: FUNCTION "update_num_groups"(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."update_num_groups"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_num_groups"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_num_groups"() TO "service_role";


--
-- Name: FUNCTION "upsert_participation"("current_event_id" bigint, "current_user_id" "uuid", "current_status" "text"); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION "public"."upsert_participation"("current_event_id" bigint, "current_user_id" "uuid", "current_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_participation"("current_event_id" bigint, "current_user_id" "uuid", "current_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_participation"("current_event_id" bigint, "current_user_id" "uuid", "current_status" "text") TO "service_role";


--
-- Name: TABLE "pg_stat_statements"; Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON TABLE "extensions"."pg_stat_statements" FROM "postgres";
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements" TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements" TO "dashboard_user";


--
-- Name: TABLE "pg_stat_statements_info"; Type: ACL; Schema: extensions; Owner: postgres
--

-- REVOKE ALL ON TABLE "extensions"."pg_stat_statements_info" FROM "postgres";
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements_info" TO "postgres" WITH GRANT OPTION;
-- GRANT ALL ON TABLE "extensions"."pg_stat_statements_info" TO "dashboard_user";


--
-- Name: SEQUENCE "seq_schema_version"; Type: ACL; Schema: graphql; Owner: supabase_admin
--

-- GRANT ALL ON SEQUENCE "graphql"."seq_schema_version" TO "postgres";
-- GRANT ALL ON SEQUENCE "graphql"."seq_schema_version" TO "anon";
-- GRANT ALL ON SEQUENCE "graphql"."seq_schema_version" TO "authenticated";
-- GRANT ALL ON SEQUENCE "graphql"."seq_schema_version" TO "service_role";


--
-- Name: TABLE "decrypted_key"; Type: ACL; Schema: pgsodium; Owner: supabase_admin
--

-- GRANT ALL ON TABLE "pgsodium"."decrypted_key" TO "pgsodium_keyholder";


--
-- Name: TABLE "masking_rule"; Type: ACL; Schema: pgsodium; Owner: supabase_admin
--

-- GRANT ALL ON TABLE "pgsodium"."masking_rule" TO "pgsodium_keyholder";


--
-- Name: TABLE "mask_columns"; Type: ACL; Schema: pgsodium; Owner: supabase_admin
--

-- GRANT ALL ON TABLE "pgsodium"."mask_columns" TO "pgsodium_keyholder";


--
-- Name: TABLE "groups"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."groups" TO "anon";
GRANT ALL ON TABLE "public"."groups" TO "authenticated";
GRANT ALL ON TABLE "public"."groups" TO "service_role";


--
-- Name: SEQUENCE "Groups_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."Groups_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Groups_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Groups_id_seq" TO "service_role";


--
-- Name: TABLE "members"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."members" TO "anon";
GRANT ALL ON TABLE "public"."members" TO "authenticated";
GRANT ALL ON TABLE "public"."members" TO "service_role";


--
-- Name: SEQUENCE "Members_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."Members_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."Members_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."Members_id_seq" TO "service_role";


--
-- Name: TABLE "events"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";


--
-- Name: SEQUENCE "events_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."events_id_seq" TO "service_role";


--
-- Name: TABLE "friend_requests"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."friend_requests" TO "anon";
GRANT ALL ON TABLE "public"."friend_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."friend_requests" TO "service_role";


--
-- Name: SEQUENCE "friend_requests_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."friend_requests_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."friend_requests_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."friend_requests_id_seq" TO "service_role";


--
-- Name: TABLE "friends"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."friends" TO "anon";
GRANT ALL ON TABLE "public"."friends" TO "authenticated";
GRANT ALL ON TABLE "public"."friends" TO "service_role";


--
-- Name: SEQUENCE "friends_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."friends_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."friends_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."friends_id_seq" TO "service_role";


--
-- Name: TABLE "invitations"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."invitations" TO "anon";
GRANT ALL ON TABLE "public"."invitations" TO "authenticated";
GRANT ALL ON TABLE "public"."invitations" TO "service_role";


--
-- Name: SEQUENCE "invitations__id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."invitations__id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."invitations__id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."invitations__id_seq" TO "service_role";


--
-- Name: TABLE "participations"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."participations" TO "anon";
GRANT ALL ON TABLE "public"."participations" TO "authenticated";
GRANT ALL ON TABLE "public"."participations" TO "service_role";


--
-- Name: SEQUENCE "participations_id_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE "public"."participations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."participations_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."participations_id_seq" TO "service_role";


--
-- Name: TABLE "profiles"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";


--
-- PostgreSQL database dump complete
--

RESET ALL;
