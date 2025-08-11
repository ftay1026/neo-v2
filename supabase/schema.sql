

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


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."add_credits"("p_customer_id" "text", "p_amount" integer, "p_description" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    -- Log the credit addition in the transactions table
    INSERT INTO public.credit_transactions (customer_id, amount, description)
    VALUES (p_customer_id, p_amount, p_description);

    -- Insert or update the credits table with the added credits
    INSERT INTO public.credits (customer_id, credits)
    VALUES (p_customer_id, p_amount)
    ON CONFLICT (customer_id)
    DO UPDATE SET credits = public.credits.credits + p_amount, updated_at = now();
END;
$$;


ALTER FUNCTION "public"."add_credits"("p_customer_id" "text", "p_amount" integer, "p_description" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_and_deduct_credits"("p_customer_id" "text", "p_required_credits" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_current_credits int;
BEGIN
    -- Retrieve current credits for the given customer
    SELECT credits INTO v_current_credits
    FROM public.credits
    WHERE customer_id = p_customer_id;

    -- Check if the customer has sufficient credits
    IF v_current_credits IS NULL OR v_current_credits < p_required_credits THEN
        RETURN false; -- Insufficient credits, function will return false
    END IF;

    -- Deduct the specified number of credits
    UPDATE public.credits
    SET credits = credits - p_required_credits,
        updated_at = now()
    WHERE customer_id = p_customer_id;

    -- Log the deduction in the transactions table
    INSERT INTO public.credit_transactions (customer_id, amount, description)
    VALUES (p_customer_id, -p_required_credits, 'Chat API usage');

    RETURN true; -- Deduction was successful
END;
$$;


ALTER FUNCTION "public"."check_and_deduct_credits"("p_customer_id" "text", "p_required_credits" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_direct_file_and_chunks"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_document_id BIGINT;
BEGIN
  -- Insert new direct file document
  INSERT INTO documents (
    user_id, 
    title, 
    content, 
    name, 
    file_type, 
    file_extension, 
    is_direct_file,
    last_modified
  )
  VALUES (
    p_user_id, 
    p_title, 
    p_content, 
    p_title, -- name same as title for direct files
    'direct/text', 
    'txt', 
    TRUE,
    NOW()
  )
  RETURNING id INTO v_document_id;
  
  -- Insert chunks
  INSERT INTO document_sections (document_id, chunk_index, content, embedding)
  SELECT 
    v_document_id,
    (chunk->>'chunk_index')::INT,
    chunk->>'content',
    (chunk->>'embedding')::vector(1536)
  FROM jsonb_array_elements(p_chunks) AS chunk;
  
  RETURN v_document_id;
END;
$$;


ALTER FUNCTION "public"."create_direct_file_and_chunks"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_direct_file_and_chunks_by_project"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb", "p_project_id" "uuid") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_document_id BIGINT;
BEGIN
  -- Insert new direct file document with project_id
  INSERT INTO documents (
    user_id, 
    title, 
    content, 
    name, 
    file_type, 
    file_extension, 
    is_direct_file,
    last_modified,
    project_id  -- Added project_id
  )
  VALUES (
    p_user_id, 
    p_title, 
    p_content, 
    p_title, -- name same as title for direct files
    'direct/text', 
    'txt', 
    TRUE,
    NOW(),
    p_project_id  -- Added project_id parameter
  )
  RETURNING id INTO v_document_id;
  
  -- Insert chunks
  INSERT INTO document_sections (document_id, chunk_index, content, embedding)
  SELECT 
    v_document_id,
    (chunk->>'chunk_index')::INT,
    chunk->>'content',
    (chunk->>'embedding')::vector(1536)
  FROM jsonb_array_elements(p_chunks) AS chunk;
  
  RETURN v_document_id;
END;
$$;


ALTER FUNCTION "public"."create_direct_file_and_chunks_by_project"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb", "p_project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_credit_summary"("p_customer_id" "text") RETURNS TABLE("total_purchased" bigint, "total_used" bigint, "current_balance" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as total_purchased,
    COALESCE(ABS(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END)), 0) as total_used,
    COALESCE((SELECT credits FROM public.credits WHERE customer_id = p_customer_id), 0) as current_balance
  FROM public.credit_transactions
  WHERE customer_id = p_customer_id;
END;
$$;


ALTER FUNCTION "public"."get_credit_summary"("p_customer_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_monthly_credit_data"("p_customer_id" "text") RETURNS TABLE("month_year" "text", "purchased" bigint, "used" bigint, "net_credits" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    TO_CHAR(DATE_TRUNC('month', ct.created_at), 'Month YYYY') as month_year,
    COALESCE(SUM(CASE WHEN ct.amount > 0 THEN ct.amount ELSE 0 END), 0) as purchased,
    COALESCE(ABS(SUM(CASE WHEN ct.amount < 0 THEN ct.amount ELSE 0 END)), 0) as used,
    COALESCE(SUM(ct.amount), 0) as net_credits
  FROM public.credit_transactions ct
  WHERE ct.customer_id = p_customer_id
  GROUP BY DATE_TRUNC('month', ct.created_at)
  ORDER BY DATE_TRUNC('month', ct.created_at) DESC
  LIMIT 12; -- Last 12 months
END;
$$;


ALTER FUNCTION "public"."get_monthly_credit_data"("p_customer_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_recent_projects_with_activity"("p_limit" integer DEFAULT 8) RETURNS TABLE("id" "uuid", "name" "text", "description" "text", "is_default" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "last_activity" timestamp with time zone, "chat_count" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.name,
    p.description,
    p.is_default,
    p.created_at,
    p.updated_at,
    COALESCE(MAX(c.created_at), p.updated_at) as last_activity,
    COUNT(c.id)::INTEGER as chat_count
  FROM projects p
  LEFT JOIN chats c ON p.id = c.project_id
  WHERE p.user_id = auth.uid()
  GROUP BY p.id, p.name, p.description, p.is_default, p.created_at, p.updated_at
  ORDER BY last_activity DESC
  LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_recent_projects_with_activity"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_signup_credits"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    signup_credits_amount INTEGER := 100;
    signup_description TEXT := 'Welcome bonus - 100 free credits to get started';
    user_email TEXT;
BEGIN
    -- Get user email with better fallback handling
    user_email := COALESCE(NEW.email, NEW.raw_user_meta_data->>'email');
    
    -- If still no email, create a synthetic one
    IF user_email IS NULL THEN
        user_email := NEW.id::text || '@neo.local';
    END IF;

    -- Create customer record using email as customer_id (HitPay pattern)
    INSERT INTO public.customers (customer_id, email, created_at, updated_at)
    VALUES (
        user_email,  -- email as customer_id for HitPay compatibility
        user_email,  -- email field
        NOW(),
        NOW()
    )
    ON CONFLICT (customer_id) DO NOTHING;

    -- Grant signup credits using existing add_credits function
    PERFORM add_credits(
        user_email,  -- customer_id (email)
        signup_credits_amount,
        signup_description
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't fail the user creation
        RAISE WARNING 'Failed to grant signup credits to user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."grant_signup_credits"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_project_id uuid;
BEGIN
    -- Create user profile (existing logic)
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
    
    -- Create default project for new user
    INSERT INTO public.projects (user_id, name, description, is_default)
    VALUES (new.id, 'Default Project', 'Your default project', true)
    RETURNING id INTO v_project_id;
    
    RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."match_document_sections_by_project"("query_embedding" "extensions"."vector", "match_threshold" double precision DEFAULT 0.7, "match_count" integer DEFAULT 5, "p_user_id" "uuid" DEFAULT "auth"."uid"(), "p_project_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" bigint, "content" "text", "filename" "text", "similarity" double precision)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ds.id,
    ds.content,
    d.name AS filename,
    (ds.embedding <#> query_embedding) * -1 AS similarity
  FROM document_sections ds
  JOIN documents d ON ds.document_id = d.id
  WHERE d.user_id = p_user_id
    AND (p_project_id IS NULL OR d.project_id = p_project_id)
    AND ds.embedding <#> query_embedding < -match_threshold
  ORDER BY ds.embedding <#> query_embedding
  LIMIT match_count;
END;
$$;


ALTER FUNCTION "public"."match_document_sections_by_project"("query_embedding" "extensions"."vector", "match_threshold" double precision, "match_count" integer, "p_user_id" "uuid", "p_project_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_direct_file_and_chunks"("p_document_id" bigint, "p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Update document
  UPDATE documents
  SET 
    title = p_title,
    content = p_content,
    name = p_title,
    last_modified = NOW(),
    updated_at = NOW()
  WHERE id = p_document_id 
    AND user_id = p_user_id 
    AND is_direct_file = TRUE;
  
  -- Delete existing chunks
  DELETE FROM document_sections 
  WHERE document_id = p_document_id;
  
  -- Insert new chunks
  INSERT INTO document_sections (document_id, chunk_index, content, embedding)
  SELECT 
    p_document_id,
    (chunk->>'chunk_index')::INT,
    chunk->>'content',
    (chunk->>'embedding')::vector(1536)
  FROM jsonb_array_elements(p_chunks) AS chunk;
  
  RETURN p_document_id;
END;
$$;


ALTER FUNCTION "public"."update_direct_file_and_chunks"("p_document_id" bigint, "p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_document_id BIGINT;
BEGIN
  -- Upsert document
  INSERT INTO documents (user_id, drive_file_id, name, last_modified)
  VALUES (p_user_id, p_drive_file_id, p_name, p_last_modified)
  ON CONFLICT (user_id, drive_file_id) 
  DO UPDATE SET 
    name = EXCLUDED.name,
    last_modified = EXCLUDED.last_modified,
    updated_at = NOW()
  RETURNING id INTO v_document_id;
  
  -- Delete existing chunks
  DELETE FROM document_sections 
  WHERE document_id = v_document_id;
  
  -- Insert new chunks
  INSERT INTO document_sections (document_id, chunk_index, content, embedding)
  SELECT 
    v_document_id,
    (chunk->>'chunk_index')::INT,
    chunk->>'content',
    (chunk->>'embedding')::vector(1536)
  FROM jsonb_array_elements(p_chunks) AS chunk;
  
  RETURN v_document_id;
END;
$$;


ALTER FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_file_type" "text", "p_file_extension" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_document_id BIGINT;
BEGIN
  -- Upsert document
  INSERT INTO documents (
    user_id, drive_file_id, name, file_type, file_extension, last_modified
  )
  VALUES (
    p_user_id, p_drive_file_id, p_name, p_file_type, p_file_extension, p_last_modified
  )
  ON CONFLICT (user_id, drive_file_id) 
  DO UPDATE SET 
    name = EXCLUDED.name,
    file_type = EXCLUDED.file_type,
    file_extension = EXCLUDED.file_extension,
    last_modified = EXCLUDED.last_modified,
    updated_at = NOW()
  RETURNING id INTO v_document_id;
  
  -- Delete existing chunks
  DELETE FROM document_sections 
  WHERE document_id = v_document_id;
  
  -- Insert new chunks
  INSERT INTO document_sections (document_id, chunk_index, content, embedding)
  SELECT 
    v_document_id,
    (chunk->>'chunk_index')::INT,
    chunk->>'content',
    (chunk->>'embedding')::vector(1536)
  FROM jsonb_array_elements(p_chunks) AS chunk;
  
  RETURN v_document_id;
END;
$$;


ALTER FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_file_type" "text", "p_file_extension" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."chats" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "visibility" character varying(7) DEFAULT 'private'::character varying NOT NULL,
    "project_id" "uuid" NOT NULL,
    CONSTRAINT "chats_visibility_check" CHECK ((("visibility")::"text" = ANY (ARRAY[('public'::character varying)::"text", ('private'::character varying)::"text"])))
);


ALTER TABLE "public"."chats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credit_transactions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "customer_id" "text" NOT NULL,
    "amount" integer NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."credit_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credits" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "customer_id" "text" NOT NULL,
    "credits" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."credits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "customer_id" "text" NOT NULL,
    "email" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."document_sections" (
    "id" bigint NOT NULL,
    "document_id" bigint NOT NULL,
    "chunk_index" integer NOT NULL,
    "content" "text" NOT NULL,
    "embedding" "extensions"."vector"(1536),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."document_sections" OWNER TO "postgres";


ALTER TABLE "public"."document_sections" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."document_sections_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "drive_file_id" "text",
    "file_type" "text" DEFAULT 'text/plain'::"text" NOT NULL,
    "file_extension" "text" DEFAULT 'txt'::"text" NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "last_modified" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "title" "text",
    "content" "text",
    "is_direct_file" boolean DEFAULT false,
    "project_id" "uuid" NOT NULL,
    CONSTRAINT "documents_file_type_check" CHECK (("file_type" = ANY (ARRAY['text/plain'::"text", 'text/markdown'::"text", 'application/pdf'::"text", 'direct/text'::"text"])))
);


ALTER TABLE "public"."documents" OWNER TO "postgres";


ALTER TABLE "public"."documents" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."documents_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."drive_connections" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "refresh_token" "text" NOT NULL,
    "folder_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."drive_connections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "chat_id" "uuid" NOT NULL,
    "role" character varying(10) NOT NULL,
    "parts" "jsonb" NOT NULL,
    "attachments" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "messages_role_check" CHECK ((("role")::"text" = ANY (ARRAY[('user'::character varying)::"text", ('assistant'::character varying)::"text", ('system'::character varying)::"text"])))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "website" "text",
    CONSTRAINT "username_length" CHECK (("char_length"("username") >= 3))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credit_transactions"
    ADD CONSTRAINT "credit_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credits"
    ADD CONSTRAINT "credits_customer_id_key" UNIQUE ("customer_id");



ALTER TABLE ONLY "public"."credits"
    ADD CONSTRAINT "credits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("customer_id");



ALTER TABLE ONLY "public"."document_sections"
    ADD CONSTRAINT "document_sections_document_id_chunk_index_key" UNIQUE ("document_id", "chunk_index");



ALTER TABLE ONLY "public"."document_sections"
    ADD CONSTRAINT "document_sections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."drive_connections"
    ADD CONSTRAINT "drive_connections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."drive_connections"
    ADD CONSTRAINT "drive_connections_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "one_default_project_per_user" UNIQUE ("user_id", "is_default") DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



CREATE INDEX "chats_project_id_idx" ON "public"."chats" USING "btree" ("project_id");



CREATE INDEX "credit_transactions_customer_id_idx" ON "public"."credit_transactions" USING "btree" ("customer_id");



CREATE INDEX "credits_customer_id_idx" ON "public"."credits" USING "btree" ("customer_id");



CREATE INDEX "customers_email_idx" ON "public"."customers" USING "btree" ("email");



CREATE INDEX "document_sections_embedding_idx" ON "public"."document_sections" USING "hnsw" ("embedding" "extensions"."vector_ip_ops") WITH ("m"='16', "ef_construction"='64');



CREATE UNIQUE INDEX "documents_project_drive_file_id_key" ON "public"."documents" USING "btree" ("project_id", "drive_file_id") WHERE ("drive_file_id" IS NOT NULL);



CREATE INDEX "documents_project_id_idx" ON "public"."documents" USING "btree" ("project_id");



CREATE UNIQUE INDEX "documents_project_title_key" ON "public"."documents" USING "btree" ("project_id", "title") WHERE ("is_direct_file" = true);



CREATE INDEX "idx_documents_file_type" ON "public"."documents" USING "btree" ("file_type");



CREATE INDEX "idx_documents_title_search" ON "public"."documents" USING "gin" ("to_tsvector"('"english"'::"regconfig", "title")) WHERE ("is_direct_file" = true);



CREATE INDEX "idx_documents_user_direct_files" ON "public"."documents" USING "btree" ("user_id", "is_direct_file", "created_at" DESC) WHERE ("is_direct_file" = true);



CREATE UNIQUE INDEX "projects_user_default_unique" ON "public"."projects" USING "btree" ("user_id") WHERE ("is_default" = true);



ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credit_transactions"
    ADD CONSTRAINT "credit_transactions_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("customer_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credits"
    ADD CONSTRAINT "credits_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("customer_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."document_sections"
    ADD CONSTRAINT "document_sections_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."drive_connections"
    ADD CONSTRAINT "drive_connections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "public"."chats"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Allow service role to insert transactions" ON "public"."credit_transactions" FOR INSERT TO "service_role" WITH CHECK (true);



CREATE POLICY "Allow service role to update credits" ON "public"."credits" FOR UPDATE TO "service_role" USING (true);



CREATE POLICY "Allow user to read their credits via user_id" ON "public"."credits" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."customers"
  WHERE (("customers"."customer_id" = "credits"."customer_id") AND ("customers"."email" = "auth"."email"())))));



CREATE POLICY "Allow user to read their transactions via user_id" ON "public"."credit_transactions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."customers"
  WHERE (("customers"."customer_id" = "credit_transactions"."customer_id") AND ("customers"."email" = "auth"."email"())))));



CREATE POLICY "Disallow deletes by users" ON "public"."credit_transactions" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (false);



CREATE POLICY "Disallow deletes by users" ON "public"."credits" AS RESTRICTIVE FOR DELETE TO "authenticated" USING (false);



CREATE POLICY "Disallow inserts by users" ON "public"."credit_transactions" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "Disallow inserts by users" ON "public"."credits" AS RESTRICTIVE FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "Disallow updates by users" ON "public"."credit_transactions" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (false);



CREATE POLICY "Disallow updates by users" ON "public"."credits" AS RESTRICTIVE FOR UPDATE TO "authenticated" USING (false);



CREATE POLICY "Enable read access for authenticated users to customers" ON "public"."customers" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Messages in public chats can be viewed by anyone" ON "public"."messages" FOR SELECT USING (("chat_id" IN ( SELECT "chats"."id"
   FROM "public"."chats"
  WHERE (("chats"."visibility")::"text" = 'public'::"text"))));



CREATE POLICY "Public chats can be viewed by anyone" ON "public"."chats" FOR SELECT USING ((("visibility")::"text" = 'public'::"text"));



CREATE POLICY "Service role can manage drive connections" ON "public"."drive_connections" USING (true);



CREATE POLICY "Users can create direct files" ON "public"."documents" FOR INSERT TO "authenticated" WITH CHECK ((("auth"."uid"() = "user_id") AND ("is_direct_file" = true) AND ("drive_file_id" IS NULL)));



CREATE POLICY "Users can delete sections from their own documents" ON "public"."document_sections" FOR DELETE TO "authenticated" USING (("document_id" IN ( SELECT "documents"."id"
   FROM "public"."documents"
  WHERE ("documents"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can delete their own chats" ON "public"."chats" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own documents" ON "public"."documents" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own non-default projects" ON "public"."projects" FOR DELETE TO "authenticated" USING ((("auth"."uid"() = "user_id") AND ("is_default" = false)));



CREATE POLICY "Users can insert document sections" ON "public"."document_sections" FOR INSERT TO "authenticated" WITH CHECK (("document_id" IN ( SELECT "documents"."id"
   FROM "public"."documents"
  WHERE ("documents"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can insert documents" ON "public"."documents" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert messages to their own chats" ON "public"."messages" FOR INSERT WITH CHECK (("chat_id" IN ( SELECT "chats"."id"
   FROM "public"."chats"
  WHERE ("chats"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can insert their own chats" ON "public"."chats" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can insert their own projects" ON "public"."projects" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can query their own document sections" ON "public"."document_sections" FOR SELECT TO "authenticated" USING (("document_id" IN ( SELECT "documents"."id"
   FROM "public"."documents"
  WHERE ("documents"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can query their own documents" ON "public"."documents" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can update their own chats" ON "public"."chats" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own documents" ON "public"."documents" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own projects" ON "public"."projects" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view messages of their own chats" ON "public"."messages" FOR SELECT USING (("chat_id" IN ( SELECT "chats"."id"
   FROM "public"."chats"
  WHERE ("chats"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their own chats" ON "public"."chats" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own drive connections" ON "public"."drive_connections" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their own profile." ON "public"."profiles" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can view their own projects" ON "public"."projects" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."chats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."credit_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."credits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."document_sections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."drive_connections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."add_credits"("p_customer_id" "text", "p_amount" integer, "p_description" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_and_deduct_credits"("p_customer_id" "text", "p_required_credits" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_direct_file_and_chunks"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_direct_file_and_chunks"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_direct_file_and_chunks"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_direct_file_and_chunks_by_project"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb", "p_project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_direct_file_and_chunks_by_project"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb", "p_project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_direct_file_and_chunks_by_project"("p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb", "p_project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_credit_summary"("p_customer_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_credit_summary"("p_customer_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_credit_summary"("p_customer_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_monthly_credit_data"("p_customer_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_monthly_credit_data"("p_customer_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_monthly_credit_data"("p_customer_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_recent_projects_with_activity"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_recent_projects_with_activity"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_recent_projects_with_activity"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."grant_signup_credits"() TO "anon";
GRANT ALL ON FUNCTION "public"."grant_signup_credits"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."grant_signup_credits"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."match_document_sections_by_project"("query_embedding" "extensions"."vector", "match_threshold" double precision, "match_count" integer, "p_user_id" "uuid", "p_project_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."match_document_sections_by_project"("query_embedding" "extensions"."vector", "match_threshold" double precision, "match_count" integer, "p_user_id" "uuid", "p_project_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."match_document_sections_by_project"("query_embedding" "extensions"."vector", "match_threshold" double precision, "match_count" integer, "p_user_id" "uuid", "p_project_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_direct_file_and_chunks"("p_document_id" bigint, "p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_direct_file_and_chunks"("p_document_id" bigint, "p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_direct_file_and_chunks"("p_document_id" bigint, "p_user_id" "uuid", "p_title" "text", "p_content" "text", "p_chunks" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_file_type" "text", "p_file_extension" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_file_type" "text", "p_file_extension" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_document_and_chunks"("p_user_id" "uuid", "p_drive_file_id" "text", "p_name" "text", "p_file_type" "text", "p_file_extension" "text", "p_last_modified" timestamp with time zone, "p_chunks" "jsonb") TO "service_role";



GRANT ALL ON TABLE "public"."chats" TO "anon";
GRANT ALL ON TABLE "public"."chats" TO "authenticated";
GRANT ALL ON TABLE "public"."chats" TO "service_role";



GRANT ALL ON TABLE "public"."credit_transactions" TO "anon";
GRANT ALL ON TABLE "public"."credit_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."credits" TO "anon";
GRANT ALL ON TABLE "public"."credits" TO "authenticated";
GRANT ALL ON TABLE "public"."credits" TO "service_role";



GRANT ALL ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT ALL ON TABLE "public"."document_sections" TO "anon";
GRANT ALL ON TABLE "public"."document_sections" TO "authenticated";
GRANT ALL ON TABLE "public"."document_sections" TO "service_role";



GRANT ALL ON SEQUENCE "public"."document_sections_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."document_sections_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."document_sections_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."documents" TO "anon";
GRANT ALL ON TABLE "public"."documents" TO "authenticated";
GRANT ALL ON TABLE "public"."documents" TO "service_role";



GRANT ALL ON SEQUENCE "public"."documents_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."documents_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."documents_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."drive_connections" TO "anon";
GRANT ALL ON TABLE "public"."drive_connections" TO "authenticated";
GRANT ALL ON TABLE "public"."drive_connections" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."projects" TO "anon";
GRANT ALL ON TABLE "public"."projects" TO "authenticated";
GRANT ALL ON TABLE "public"."projects" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






RESET ALL;
