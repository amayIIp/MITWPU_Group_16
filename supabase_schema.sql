-- =============================================================
--  Spasht / Stuttering App — Supabase Schema
--  New Project: woatlzolrisargsmpeji.supabase.co
--
--  HOW TO RUN:
--    Supabase Dashboard → SQL Editor → paste this entire file → Run
--
--  Fixes vs old schema:
--    • journeys          — added PRIMARY KEY (user_id, name)
--    • daily_tasks       — id kept as integer; explicit composite PK
--    • user_awards       — added UNIQUE(user_id, award_id) so upsert works
--    • session_letter_stats — onConflict clause now targets (session_id, letter)
--    • has_pending_sync  — PostgreSQL function created
--    • RLS policies      — every table is locked to the owning user
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 0.  Enable UUID extension (needed for gen_random_uuid())
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ─────────────────────────────────────────────────────────────
-- 1.  PROFILES
--     One row per auth user. Created on first sign-up / first login.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
    id                      uuid        NOT NULL,
    first_name              text,
    last_name               text,
    dob                     text,
    mobile                  text,
    is_onboarding_completed boolean     NOT NULL DEFAULT false,
    updated_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT profiles_pkey PRIMARY KEY (id),
    CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles: owner can select"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "profiles: owner can insert"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles: owner can update"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles: owner can delete"
    ON public.profiles FOR DELETE
    USING (auth.uid() = id);


-- ─────────────────────────────────────────────────────────────
-- 2.  STREAKS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.streaks (
    user_id             uuid    NOT NULL,
    current_streak      integer NOT NULL DEFAULT 0,
    last_completed_date text,
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT streaks_pkey PRIMARY KEY (user_id),
    CONSTRAINT streaks_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "streaks: owner can select"
    ON public.streaks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "streaks: owner can insert"
    ON public.streaks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "streaks: owner can update"
    ON public.streaks FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "streaks: owner can delete"
    ON public.streaks FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 3.  USER GOALS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_goals (
    user_id    uuid    NOT NULL,
    goal_name  text    NOT NULL,
    goal_value integer NOT NULL DEFAULT 0,

    CONSTRAINT user_goals_pkey PRIMARY KEY (user_id, goal_name),
    CONSTRAINT user_goals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.user_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_goals: owner can select"
    ON public.user_goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_goals: owner can insert"
    ON public.user_goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_goals: owner can update"
    ON public.user_goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "user_goals: owner can delete"
    ON public.user_goals FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 4.  JOURNEYS
--     FIX: explicit PRIMARY KEY (user_id, name) so upsert works.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.journeys (
    user_id      uuid    NOT NULL,
    name         text    NOT NULL,
    is_completed boolean NOT NULL DEFAULT false,
    updated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT journeys_pkey PRIMARY KEY (user_id, name),
    CONSTRAINT journeys_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.journeys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "journeys: owner can select"
    ON public.journeys FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "journeys: owner can insert"
    ON public.journeys FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "journeys: owner can update"
    ON public.journeys FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "journeys: owner can delete"
    ON public.journeys FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 5.  DAILY TASKS
--     id is integer (local SQLite rowid). PK = (id, user_id).
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.daily_tasks (
    id           integer NOT NULL,
    user_id      uuid    NOT NULL,
    name         text    NOT NULL,
    description  text,
    duration     integer,
    is_completed boolean NOT NULL DEFAULT false,
    updated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT daily_tasks_pkey PRIMARY KEY (id, user_id),
    CONSTRAINT daily_tasks_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.daily_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_tasks: owner can select"
    ON public.daily_tasks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "daily_tasks: owner can insert"
    ON public.daily_tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "daily_tasks: owner can update"
    ON public.daily_tasks FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "daily_tasks: owner can delete"
    ON public.daily_tasks FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 6.  EXERCISE LOGS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.exercise_logs (
    id              text    NOT NULL,
    user_id         uuid    NOT NULL,
    exercise_name   text    NOT NULL,
    source          text    NOT NULL,
    duration        integer NOT NULL DEFAULT 0,
    completion_date text    NOT NULL,
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT exercise_logs_pkey PRIMARY KEY (id),
    CONSTRAINT exercise_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.exercise_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exercise_logs: owner can select"
    ON public.exercise_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "exercise_logs: owner can insert"
    ON public.exercise_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "exercise_logs: owner can update"
    ON public.exercise_logs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "exercise_logs: owner can delete"
    ON public.exercise_logs FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 7.  READING SESSIONS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reading_sessions (
    id                      text             NOT NULL,
    user_id                 uuid             NOT NULL,
    date                    double precision NOT NULL,
    duration                double precision NOT NULL,
    fluency_score           integer          NOT NULL DEFAULT 0,
    repetition_percent      double precision NOT NULL DEFAULT 0,
    prolongation_percent    double precision NOT NULL DEFAULT 0,
    block_percent           double precision NOT NULL DEFAULT 0,
    correct_percent         double precision NOT NULL DEFAULT 0,
    longest_smooth_paragraph integer         NOT NULL DEFAULT 0,
    updated_at              timestamptz      NOT NULL DEFAULT now(),

    CONSTRAINT reading_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT reading_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.reading_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reading_sessions: owner can select"
    ON public.reading_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "reading_sessions: owner can insert"
    ON public.reading_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reading_sessions: owner can update"
    ON public.reading_sessions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "reading_sessions: owner can delete"
    ON public.reading_sessions FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 8.  TROUBLED WORDS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.troubled_words (
    id           text NOT NULL,
    session_id   text NOT NULL,
    user_id      uuid NOT NULL,
    word         text NOT NULL,
    type         text NOT NULL,
    first_letter text,

    CONSTRAINT troubled_words_pkey PRIMARY KEY (id),
    CONSTRAINT troubled_words_session_id_fkey
        FOREIGN KEY (session_id) REFERENCES public.reading_sessions(id) ON DELETE CASCADE,
    CONSTRAINT troubled_words_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.troubled_words ENABLE ROW LEVEL SECURITY;

CREATE POLICY "troubled_words: owner can select"
    ON public.troubled_words FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "troubled_words: owner can insert"
    ON public.troubled_words FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "troubled_words: owner can update"
    ON public.troubled_words FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "troubled_words: owner can delete"
    ON public.troubled_words FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 9.  SESSION LETTER STATS
--     FIX: explicit PK (session_id, letter) so upsert resolves cleanly.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.session_letter_stats (
    session_id    text    NOT NULL,
    user_id       uuid    NOT NULL,
    letter        text    NOT NULL,
    stutter_count integer NOT NULL DEFAULT 0,

    CONSTRAINT session_letter_stats_pkey PRIMARY KEY (session_id, letter),
    CONSTRAINT session_letter_stats_session_id_fkey
        FOREIGN KEY (session_id) REFERENCES public.reading_sessions(id) ON DELETE CASCADE,
    CONSTRAINT session_letter_stats_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.session_letter_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session_letter_stats: owner can select"
    ON public.session_letter_stats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "session_letter_stats: owner can insert"
    ON public.session_letter_stats FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "session_letter_stats: owner can update"
    ON public.session_letter_stats FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "session_letter_stats: owner can delete"
    ON public.session_letter_stats FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 10. LETTER STATS  (cumulative per-user totals)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.letter_stats (
    user_id uuid    NOT NULL,
    letter  text    NOT NULL,
    count   integer NOT NULL DEFAULT 0,

    CONSTRAINT letter_stats_pkey PRIMARY KEY (user_id, letter),
    CONSTRAINT letter_stats_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.letter_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "letter_stats: owner can select"
    ON public.letter_stats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "letter_stats: owner can insert"
    ON public.letter_stats FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "letter_stats: owner can update"
    ON public.letter_stats FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "letter_stats: owner can delete"
    ON public.letter_stats FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 11. CONVERSATION SESSIONS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.conversation_sessions (
    id                  text             NOT NULL,
    user_id             uuid             NOT NULL,
    date                double precision NOT NULL,
    duration            double precision NOT NULL,
    filler_word_percent double precision NOT NULL DEFAULT 0,
    longest_smooth_talk integer          NOT NULL DEFAULT 0,
    updated_at          timestamptz      NOT NULL DEFAULT now(),

    CONSTRAINT conversation_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT conversation_sessions_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.conversation_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversation_sessions: owner can select"
    ON public.conversation_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "conversation_sessions: owner can insert"
    ON public.conversation_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "conversation_sessions: owner can update"
    ON public.conversation_sessions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "conversation_sessions: owner can delete"
    ON public.conversation_sessions FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 12. USER AWARDS
--     FIX: added UNIQUE(user_id, award_id) so upsert(onConflict:)
--     resolves on the right target instead of generating new rows.
--     id is kept as text but is now derived as "<user_id>_<award_id>"
--     from Swift — still a valid UUID-free primary key.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_awards (
    id         text             NOT NULL,
    user_id    uuid             NOT NULL,
    award_id   text             NOT NULL,
    progress   double precision NOT NULL DEFAULT 0,
    status     text             NOT NULL DEFAULT 'locked',
    updated_at timestamptz      NOT NULL DEFAULT now(),

    CONSTRAINT user_awards_pkey PRIMARY KEY (id),
    CONSTRAINT user_awards_unique_award UNIQUE (user_id, award_id),
    CONSTRAINT user_awards_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.user_awards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_awards: owner can select"
    ON public.user_awards FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "user_awards: owner can insert"
    ON public.user_awards FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "user_awards: owner can update"
    ON public.user_awards FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "user_awards: owner can delete"
    ON public.user_awards FOR DELETE USING (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 13. has_pending_sync  (RPC called by hasPendingCloudChanges)
--
--     Returns TRUE if any of the user's rows were updated after
--     the supplied last_sync timestamp.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.has_pending_sync(
    last_sync  text,
    user_uuid  text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sync_time timestamptz;
    has_rows  boolean;
BEGIN
    -- Parse the ISO-8601 string; fall back to epoch on bad input.
    BEGIN
        sync_time := last_sync::timestamptz;
    EXCEPTION WHEN OTHERS THEN
        sync_time := '1970-01-01T00:00:00Z'::timestamptz;
    END;

    SELECT EXISTS (
        SELECT 1 FROM public.profiles
            WHERE id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.reading_sessions
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.conversation_sessions
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.exercise_logs
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.streaks
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.user_awards
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.journeys
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
        UNION ALL
        SELECT 1 FROM public.daily_tasks
            WHERE user_id = user_uuid::uuid AND updated_at > sync_time
    ) INTO has_rows;

    RETURN has_rows;
END;
$$;

-- Allow authenticated users to call it
GRANT EXECUTE ON FUNCTION public.has_pending_sync(text, text) TO authenticated;


-- ─────────────────────────────────────────────────────────────
-- 14. AUTO-CREATE PROFILE ROW AFTER SIGN-UP
--
--     This trigger fires after a new row is inserted in auth.users
--     (i.e., every new sign-up, including Google OAuth).
--     It creates a blank profiles row so FK constraints from other
--     tables are never violated on first push.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, first_name, is_onboarding_completed, updated_at)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'first_name',
        false,
        now()
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Drop old trigger if it exists, then recreate cleanly
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
