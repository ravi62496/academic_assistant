-- ============================================================================
-- ACADEMIC ASSISTANT - COMPLETE SUPABASE DATABASE SCHEMA WITH RLS & TRIGGERS
-- Run this SQL in your Supabase SQL Editor to initialize all required tables.
-- ============================================================================

-- 1. PROFILES TABLE (linked to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "System can insert profile" ON public.profiles;
CREATE POLICY "System can insert profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');


-- 2. COURSES TABLE
CREATE TABLE IF NOT EXISTS public.courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_name TEXT NOT NULL,
  course_code TEXT,
  professor TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own courses" ON public.courses;
CREATE POLICY "Users can view own courses" ON public.courses FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own courses" ON public.courses;
CREATE POLICY "Users can insert own courses" ON public.courses FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own courses" ON public.courses;
CREATE POLICY "Users can update own courses" ON public.courses FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own courses" ON public.courses;
CREATE POLICY "Users can delete own courses" ON public.courses FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_courses_user_id ON public.courses(user_id);


-- 3. CLASS SCHEDULES TABLE
CREATE TABLE IF NOT EXISTS public.class_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  room TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.class_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own class schedules" ON public.class_schedules;
CREATE POLICY "Users can view own class schedules" ON public.class_schedules FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own class schedules" ON public.class_schedules;
CREATE POLICY "Users can insert own class schedules" ON public.class_schedules FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own class schedules" ON public.class_schedules;
CREATE POLICY "Users can update own class schedules" ON public.class_schedules FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own class schedules" ON public.class_schedules;
CREATE POLICY "Users can delete own class schedules" ON public.class_schedules FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_class_schedules_user_day ON public.class_schedules(user_id, day_of_week);


-- 4. TASKS TABLE
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  due_at TIMESTAMPTZ,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own tasks" ON public.tasks;
CREATE POLICY "Users can view own tasks" ON public.tasks FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own tasks" ON public.tasks;
CREATE POLICY "Users can insert own tasks" ON public.tasks FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own tasks" ON public.tasks;
CREATE POLICY "Users can update own tasks" ON public.tasks FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own tasks" ON public.tasks;
CREATE POLICY "Users can delete own tasks" ON public.tasks FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_tasks_user_due ON public.tasks(user_id, due_at);


-- 5. SCHEDULE OVERRIDES TABLE
CREATE TABLE IF NOT EXISTS public.schedule_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_schedule_id UUID NOT NULL REFERENCES public.class_schedules(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type TEXT NOT NULL DEFAULT 'cancelled',
  new_start_time TEXT,
  new_end_time TEXT,
  new_room TEXT,
  new_day_of_week INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_class_date UNIQUE (user_id, class_schedule_id, date)
);

ALTER TABLE public.schedule_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own schedule overrides" ON public.schedule_overrides;
CREATE POLICY "Users can view own schedule overrides" ON public.schedule_overrides FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own schedule overrides" ON public.schedule_overrides;
CREATE POLICY "Users can insert own schedule overrides" ON public.schedule_overrides FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own schedule overrides" ON public.schedule_overrides;
CREATE POLICY "Users can update own schedule overrides" ON public.schedule_overrides FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own schedule overrides" ON public.schedule_overrides;
CREATE POLICY "Users can delete own schedule overrides" ON public.schedule_overrides FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_overrides_user_date ON public.schedule_overrides(user_id, date);


-- 6. AI CHAT MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.ai_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  tool_calls JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ai_chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own ai chat messages" ON public.ai_chat_messages;
CREATE POLICY "Users can view own ai chat messages" ON public.ai_chat_messages FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own ai chat messages" ON public.ai_chat_messages;
CREATE POLICY "Users can insert own ai chat messages" ON public.ai_chat_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own ai chat messages" ON public.ai_chat_messages;
CREATE POLICY "Users can delete own ai chat messages" ON public.ai_chat_messages FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_ai_messages_user_time ON public.ai_chat_messages(user_id, created_at);


-- 7. AUTOMATIC PROFILE CREATION TRIGGER ON AUTH SIGN-UP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email, '@', 1), 'Student'),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
    updated_at = NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- 8. SECURE ACCOUNT SELF-DELETION RPC FUNCTION
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, auth
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM public.profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
