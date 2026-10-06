-- ============================================================
-- LibraryPlus – Books Table Complete Setup
-- Run this SQL in your Supabase SQL Editor
-- ============================================================

-- 1. Create books table
CREATE TABLE IF NOT EXISTS public.books (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title          TEXT        NOT NULL,
  authors        TEXT        NOT NULL DEFAULT '',
  isbn           TEXT,
  publisher      TEXT,
  published_year INT,
  genre          TEXT,
  description    TEXT,
  shelf_location TEXT,
  total_copies   INT         NOT NULL DEFAULT 1 CHECK (total_copies >= 0),
  available_copies INT       NOT NULL DEFAULT 1 CHECK (available_copies >= 0),
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ
);

-- 2. Enable Row Level Security
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;

-- 3. Drop old policies if any
DROP POLICY IF EXISTS "Public full access books" ON public.books;

-- 4. Open full-access policy (same approach as profiles table)
CREATE POLICY "Public full access books" ON public.books
FOR ALL
TO public
USING (true)
WITH CHECK (true);

-- 5. Grant privileges
GRANT ALL ON TABLE public.books TO anon;
GRANT ALL ON TABLE public.books TO authenticated;
GRANT ALL ON TABLE public.books TO service_role;

-- 6. Performance indexes
CREATE INDEX IF NOT EXISTS idx_books_is_active     ON public.books(is_active);
CREATE INDEX IF NOT EXISTS idx_books_title         ON public.books(title);
CREATE INDEX IF NOT EXISTS idx_books_genre         ON public.books(genre);
CREATE INDEX IF NOT EXISTS idx_books_shelf         ON public.books(shelf_location);

-- ============================================================
-- Sample Book Data (10 books across various genres)
-- Deletes all existing books and re-inserts fresh sample data
-- ============================================================
DELETE FROM public.books;

INSERT INTO public.books (title, authors, isbn, publisher, published_year, genre, description, shelf_location, total_copies, available_copies, is_active)
VALUES
  (
    'About Face: The Essentials of Interaction Design',
    'Cooper, Reimann, Cronin, Noessel',
    '978-1118766576', 'Wiley', 2014, 'Design',
    'The essential guide to interaction design covering user research, prototyping, and visual interface design.',
    'Shelf A1', 3, 1, TRUE
  ),
  (
    'Don''t Make Me Think',
    'Steve Krug',
    '978-0321965516', 'New Riders', 2014, 'UX Design',
    'A common sense approach to web usability with practical guidance for web designers and developers.',
    'Shelf A1', 1, 1, TRUE
  ),
  (
    'Interaction Design: Beyond Human-Computer Interaction',
    'Preece, Rogers, Sharp',
    '978-1119547990', 'Wiley', 2019, 'Design',
    'Comprehensive introduction to the field of interaction design, exploring the design of interactive products.',
    'Shelf C4', 2, 2, TRUE
  ),
  (
    'Clean Code: A Handbook of Agile Software Craftsmanship',
    'Robert C. Martin',
    '978-0132350884', 'Prentice Hall', 2008, 'Software Engineering',
    'A guide to writing readable, maintainable code with principles for clean coding practices.',
    'Shelf B2', 4, 3, TRUE
  ),
  (
    'The Design of Everyday Things',
    'Don Norman',
    '978-0465050659', 'Basic Books', 2013, 'Design',
    'A powerful primer on how (and why) some products satisfy customers while others only frustrate them.',
    'Shelf A2', 2, 2, TRUE
  ),
  (
    'Introduction to Algorithms',
    'Cormen, Leiserson, Rivest, Stein',
    '978-0262046305', 'MIT Press', 2022, 'Computer Science',
    'The comprehensive textbook on algorithms, covering a broad range of algorithms in depth.',
    'Shelf B3', 3, 3, TRUE
  ),
  (
    'Database System Concepts',
    'Silberschatz, Korth, Sudarshan',
    '978-0078022159', 'McGraw-Hill', 2019, 'Computer Science',
    'A comprehensive introduction to database systems covering relational models, SQL, and advanced topics.',
    'Shelf C1', 2, 1, TRUE
  ),
  (
    'Atomic Habits',
    'James Clear',
    '978-0735211292', 'Avery', 2018, 'Self-Development',
    'An easy and proven way to build good habits and break bad ones using tiny changes that yield remarkable results.',
    'Shelf D1', 5, 4, TRUE
  ),
  (
    'The Pragmatic Programmer',
    'Andrew Hunt, David Thomas',
    '978-0135957059', 'Addison-Wesley', 2019, 'Software Engineering',
    'From journeyman to master — timeless lessons for software developers to become pragmatic and effective.',
    'Shelf B2', 2, 2, TRUE
  ),
  (
    'Artificial Intelligence: A Modern Approach',
    'Stuart Russell, Peter Norvig',
    '978-0134610993', 'Pearson', 2020, 'Artificial Intelligence',
    'The leading textbook in Artificial Intelligence, used in over 1400 universities in 128 countries.',
    'Shelf C2', 3, 2, TRUE
  );

-- ============================================================
-- 7. Book Reservations & Borrowing Table Setup
-- ============================================================

CREATE TABLE IF NOT EXISTS public.book_reservations (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id             UUID        NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  user_id             UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status              TEXT        NOT NULL DEFAULT 'reserved'
    CHECK (status IN ('reserved', 'borrowed', 'returned', 'cancelled')),
  qr_token            TEXT        UNIQUE,
  reserved_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  borrowed_at         TIMESTAMPTZ,
  due_date            TIMESTAMPTZ,
  returned_at         TIMESTAMPTZ,
  cancelled_at        TIMESTAMPTZ,
  cancellation_reason TEXT,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE public.book_reservations ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Public full access book_reservations" ON public.book_reservations;

-- Create policy
CREATE POLICY "Public full access book_reservations" ON public.book_reservations
FOR ALL
TO public
USING (true)
WITH CHECK (true);

-- Grant privileges
GRANT ALL ON TABLE public.book_reservations TO anon;
GRANT ALL ON TABLE public.book_reservations TO authenticated;
GRANT ALL ON TABLE public.book_reservations TO service_role;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_book_res_user    ON public.book_reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_book_res_book    ON public.book_reservations(book_id);
CREATE INDEX IF NOT EXISTS idx_book_res_status  ON public.book_reservations(status);
CREATE INDEX IF NOT EXISTS idx_book_res_qr      ON public.book_reservations(qr_token);

