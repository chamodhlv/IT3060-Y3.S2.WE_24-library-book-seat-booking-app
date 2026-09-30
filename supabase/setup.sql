-- ============================================================
-- LibraryPlus - Supabase Database RLS & Permissions Setup
-- Run this SQL in your Supabase SQL Editor
-- ============================================================

-- 1. Create table structure if not existing
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL DEFAULT '123456',
  full_name TEXT NOT NULL DEFAULT '',
  student_staff_id TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'librarian')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Ensure password column exists
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS password TEXT NOT NULL DEFAULT '123456';

-- Drop the old foreign key to auth.users (since we use direct database accounts)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 2. Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Drop all old/restrictive policies
DROP POLICY IF EXISTS "Public full access" ON public.profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
DROP POLICY IF EXISTS "Librarians can read all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Librarians can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Librarians can delete profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow all operations for anon" ON public.profiles;

-- 4. Create an open full-access policy for direct app operations
CREATE POLICY "Public full access" ON public.profiles
FOR ALL
TO public
USING (true)
WITH CHECK (true);

-- 5. Grant explicit table privileges to anon, authenticated, and service_role
GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;

-- 6. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_student_staff_id ON public.profiles(student_staff_id);
