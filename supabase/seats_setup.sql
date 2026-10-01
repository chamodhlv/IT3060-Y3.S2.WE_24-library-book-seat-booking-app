-- ============================================================
-- LibraryPlus - Seat Booking Feature Schema
-- Run this in your Supabase SQL Editor AFTER setup.sql
-- ============================================================

-- 1. SEATS TABLE
CREATE TABLE IF NOT EXISTS public.seats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,               -- e.g. "A1", "B12"
  section TEXT NOT NULL DEFAULT 'main_hall' CHECK (section IN ('main_hall', 'group_pods')),
  description TEXT,                  -- e.g. "Window side · Power outlet"
  capacity INT NOT NULL DEFAULT 1,   -- 5 for group pods
  features TEXT[] DEFAULT '{}',      -- ["window_side","power_outlet","individual"]
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- 2. SEAT BOOKINGS TABLE
CREATE TABLE IF NOT EXISTS public.seat_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seat_id UUID NOT NULL REFERENCES public.seats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  start_hour INT NOT NULL,           -- 8 = 8:00 AM
  end_hour INT NOT NULL,             -- 10 = 10:00 AM (2 hour slot)
  status TEXT NOT NULL DEFAULT 'confirmed'
    CHECK (status IN ('confirmed', 'checked_in', 'cancelled', 'expired', 'no_show')),
  qr_token TEXT UNIQUE,              -- UUID token for QR code
  check_in_time TIMESTAMPTZ,
  cancellation_reason TEXT,
  cancelled_by TEXT,                 -- 'student' | 'librarian'
  reminder_enabled BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- 3. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'info'
    CHECK (type IN ('info', 'booking_confirmed', 'booking_cancelled', 'booking_checkin', 'reminder')),
  is_read BOOLEAN NOT NULL DEFAULT false,
  related_booking_id UUID REFERENCES public.seat_bookings(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Enable RLS
ALTER TABLE public.seats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seat_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies (open for anon like profiles table)
DROP POLICY IF EXISTS "Public full access seats" ON public.seats;
CREATE POLICY "Public full access seats" ON public.seats
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public full access bookings" ON public.seat_bookings;
CREATE POLICY "Public full access bookings" ON public.seat_bookings
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public full access notifications" ON public.notifications;
CREATE POLICY "Public full access notifications" ON public.notifications
  FOR ALL TO public USING (true) WITH CHECK (true);

-- 6. Grants
GRANT ALL ON TABLE public.seats TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.seat_bookings TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;

-- 7. Indexes
CREATE INDEX IF NOT EXISTS idx_seats_section ON public.seats(section);
CREATE INDEX IF NOT EXISTS idx_seats_active ON public.seats(is_active);
CREATE INDEX IF NOT EXISTS idx_bookings_seat_date ON public.seat_bookings(seat_id, date);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON public.seat_bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.seat_bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_qr ON public.seat_bookings(qr_token);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);

-- 8. Seed: 25 Main Hall seats (A1-E5 grid)
DO $$
DECLARE
  row_label TEXT;
  col_num INT;
  seat_label TEXT;
  sort INT := 0;
  features_arr TEXT[];
BEGIN
  FOREACH row_label IN ARRAY ARRAY['A','B','C','D','E'] LOOP
    FOR col_num IN 1..5 LOOP
      seat_label := row_label || col_num::TEXT;
      -- Assign some features
      features_arr := ARRAY['individual_study_seat'];
      IF row_label = 'A' THEN features_arr := features_arr || ARRAY['window_side']; END IF;
      IF col_num = 5 THEN features_arr := features_arr || ARRAY['power_outlet']; END IF;

      INSERT INTO public.seats (label, section, capacity, features, sort_order)
      VALUES (seat_label, 'main_hall', 1, features_arr, sort)
      ON CONFLICT DO NOTHING;
      sort := sort + 1;
    END LOOP;
  END LOOP;
END $$;

-- 9. Seed: 6 Group Pods (5-person)
DO $$
DECLARE
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    INSERT INTO public.seats (label, section, capacity, features, sort_order, description)
    VALUES (
      'Pod ' || i::TEXT,
      'group_pods',
      5,
      ARRAY['group_study','whiteboard'],
      i,
      'Group study pod for up to 5 people'
    )
    ON CONFLICT DO NOTHING;
  END LOOP;
END $$;
