import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book_model.dart';
import '../models/book_reservation_model.dart';
import '../models/seat_model.dart' show generateQrToken;

/// Service for library book CRUD and reservation operations.
class BookService {
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // ─── SEED ────────────────────────────────────────────────────

  /// Seeds sample books into the database if none exist.
  /// Throws if the books table doesn't exist yet — caller should handle.
  Future<void> seedSampleBooksIfEmpty() async {
    final existing = await _client.from('books').select('id').limit(1);
    if ((existing as List).isNotEmpty) return;

    final sampleBooks = [
      {
        'title': 'About Face: The Essentials of Interaction Design',
        'authors': 'Cooper, Reimann, Cronin, Noessel',
        'isbn': '978-1118766576',
        'publisher': 'Wiley',
        'published_year': 2014,
        'genre': 'Design',
        'description':
            'The essential guide to interaction design covering user research, prototyping, and visual interface design.',
        'shelf_location': 'Shelf A1',
        'total_copies': 3,
        'available_copies': 1,
        'is_active': true,
      },
      {
        'title': "Don't Make Me Think",
        'authors': 'Steve Krug',
        'isbn': '978-0321965516',
        'publisher': 'New Riders',
        'published_year': 2014,
        'genre': 'UX Design',
        'description':
            'A common sense approach to web usability with practical guidance for web designers and developers.',
        'shelf_location': 'Shelf A1',
        'total_copies': 1,
        'available_copies': 1,
        'is_active': true,
      },
      {
        'title': 'Interaction Design: Beyond Human-Computer Interaction',
        'authors': 'Preece, Rogers, Sharp',
        'isbn': '978-1119547990',
        'publisher': 'Wiley',
        'published_year': 2019,
        'genre': 'Design',
        'description':
            'Comprehensive introduction to the field of interaction design, exploring the design of interactive products.',
        'shelf_location': 'Shelf C4',
        'total_copies': 2,
        'available_copies': 2,
        'is_active': true,
      },
      {
        'title': 'Clean Code: A Handbook of Agile Software Craftsmanship',
        'authors': 'Robert C. Martin',
        'isbn': '978-0132350884',
        'publisher': 'Prentice Hall',
        'published_year': 2008,
        'genre': 'Software Engineering',
        'description':
            'A guide to writing readable, maintainable code with principles for clean coding practices.',
        'shelf_location': 'Shelf B2',
        'total_copies': 4,
        'available_copies': 3,
        'is_active': true,
      },
      {
        'title': 'The Design of Everyday Things',
        'authors': 'Don Norman',
        'isbn': '978-0465050659',
        'publisher': 'Basic Books',
        'published_year': 2013,
        'genre': 'Design',
        'description':
            'A powerful primer on how (and why) some products satisfy customers while others only frustrate them.',
        'shelf_location': 'Shelf A2',
        'total_copies': 2,
        'available_copies': 2,
        'is_active': true,
      },
      {
        'title': 'Introduction to Algorithms',
        'authors': 'Cormen, Leiserson, Rivest, Stein',
        'isbn': '978-0262046305',
        'publisher': 'MIT Press',
        'published_year': 2022,
        'genre': 'Computer Science',
        'description':
            'The comprehensive textbook on algorithms, covering a broad range of algorithms in depth.',
        'shelf_location': 'Shelf B3',
        'total_copies': 3,
        'available_copies': 3,
        'is_active': true,
      },
      {
        'title': 'Database System Concepts',
        'authors': 'Silberschatz, Korth, Sudarshan',
        'isbn': '978-0078022159',
        'publisher': 'McGraw-Hill',
        'published_year': 2019,
        'genre': 'Computer Science',
        'description':
            'A comprehensive introduction to database systems covering relational models, SQL, and advanced topics.',
        'shelf_location': 'Shelf C1',
        'total_copies': 2,
        'available_copies': 1,
        'is_active': true,
      },
      {
        'title': 'Atomic Habits',
        'authors': 'James Clear',
        'isbn': '978-0735211292',
        'publisher': 'Avery',
        'published_year': 2018,
        'genre': 'Self-Development',
        'description':
            'An easy and proven way to build good habits and break bad ones using tiny changes that yield remarkable results.',
        'shelf_location': 'Shelf D1',
        'total_copies': 5,
        'available_copies': 4,
        'is_active': true,
      },
      {
        'title': 'The Pragmatic Programmer',
        'authors': 'Andrew Hunt, David Thomas',
        'isbn': '978-0135957059',
        'publisher': 'Addison-Wesley',
        'published_year': 2019,
        'genre': 'Software Engineering',
        'description':
            'From journeyman to master — timeless lessons for software developers to become pragmatic and effective.',
        'shelf_location': 'Shelf B2',
        'total_copies': 2,
        'available_copies': 2,
        'is_active': true,
      },
      {
        'title': 'Artificial Intelligence: A Modern Approach',
        'authors': 'Stuart Russell, Peter Norvig',
        'isbn': '978-0134610993',
        'publisher': 'Pearson',
        'published_year': 2020,
        'genre': 'Artificial Intelligence',
        'description':
            'The leading textbook in Artificial Intelligence, used in over 1400 universities in 128 countries.',
        'shelf_location': 'Shelf C2',
        'total_copies': 3,
        'available_copies': 2,
        'is_active': true,
      },
    ];

    await _client.from('books').insert(sampleBooks);
  }


  // ─── READ ─────────────────────────────────────────────────────

  /// Fetch all active books, optionally filtering by search query.
  Future<List<Book>> getBooks({String? search}) async {
    await seedSampleBooksIfEmpty();

    var query = _client.from('books').select().eq('is_active', true);

    final data = await query.order('title');
    final books = (data as List).map((e) => Book.fromMap(e)).toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return books
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.authors.toLowerCase().contains(q) ||
              (b.isbn?.toLowerCase().contains(q) ?? false) ||
              (b.shelfLocation?.toLowerCase().contains(q) ?? false) ||
              (b.genre?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return books;
  }

  /// Fetch all books including inactive (for admin view).
  Future<List<Book>> getAllBooks({String? search}) async {
    await seedSampleBooksIfEmpty();

    final data = await _client.from('books').select().order('title');
    final books = (data as List).map((e) => Book.fromMap(e)).toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return books
          .where((b) =>
              b.title.toLowerCase().contains(q) ||
              b.authors.toLowerCase().contains(q) ||
              (b.isbn?.toLowerCase().contains(q) ?? false) ||
              (b.shelfLocation?.toLowerCase().contains(q) ?? false) ||
              (b.genre?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return books;
  }

  // ─── CREATE ───────────────────────────────────────────────────

  /// Insert a new book record.
  Future<Book> createBook({
    required String title,
    required String authors,
    String? isbn,
    String? publisher,
    int? publishedYear,
    String? genre,
    String? description,
    String? shelfLocation,
    required int totalCopies,
  }) async {
    final payload = {
      'title': title.trim(),
      'authors': authors.trim(),
      if (isbn != null && isbn.isNotEmpty) 'isbn': isbn.trim(),
      if (publisher != null && publisher.isNotEmpty)
        'publisher': publisher.trim(),
      'published_year': publishedYear,
      if (genre != null && genre.isNotEmpty) 'genre': genre.trim(),
      if (description != null && description.isNotEmpty)
        'description': description.trim(),
      if (shelfLocation != null && shelfLocation.isNotEmpty)
        'shelf_location': shelfLocation.trim(),
      'total_copies': totalCopies,
      'available_copies': totalCopies,
      'is_active': true,
    };

    final result =
        await _client.from('books').insert(payload).select().single();
    return Book.fromMap(result);
  }

  // ─── UPDATE ───────────────────────────────────────────────────

  /// Update an existing book record.
  Future<Book> updateBook({
    required String id,
    required String title,
    required String authors,
    String? isbn,
    String? publisher,
    int? publishedYear,
    String? genre,
    String? description,
    String? shelfLocation,
    required int totalCopies,
    required int availableCopies,
  }) async {
    final payload = {
      'title': title.trim(),
      'authors': authors.trim(),
      'isbn': isbn?.trim(),
      'publisher': publisher?.trim(),
      'published_year': publishedYear,
      'genre': genre?.trim(),
      'description': description?.trim(),
      'shelf_location': shelfLocation?.trim(),
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final result =
        await _client.from('books').update(payload).eq('id', id).select().single();
    return Book.fromMap(result);
  }

  /// Add copies to an existing book (increases both total and available).
  Future<Book> addCopies({required String id, required int copiesToAdd}) async {
    final current = await _client
        .from('books')
        .select('total_copies, available_copies')
        .eq('id', id)
        .single();

    final newTotal = (current['total_copies'] as int) + copiesToAdd;
    final newAvailable = (current['available_copies'] as int) + copiesToAdd;

    final result = await _client
        .from('books')
        .update({
          'total_copies': newTotal,
          'available_copies': newAvailable,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return Book.fromMap(result);
  }

  // ─── DELETE / DEACTIVATE ──────────────────────────────────────

  /// Soft-delete a book by marking it inactive.
  Future<void> deactivateBook(String id) async {
    await _client.from('books').update({
      'is_active': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Hard-delete a book record.
  Future<void> deleteBook(String id) async {
    await _client.from('books').delete().eq('id', id);
  }

  // ─── BOOK RESERVATIONS & BORROWING ────────────────────────────

  /// Reserve an available copy of a book for a student.
  /// Throws Exception if no copies available or user already has an active hold/borrow.
  Future<BookReservation> reserveBook({
    required String bookId,
    required String userId,
  }) async {
    // 1. Check if user already has an active reservation or borrow for this book
    final existing = await _client
        .from('book_reservations')
        .select('id, status')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .inFilter('status', ['reserved', 'borrowed'])
        .limit(1);

    if ((existing as List).isNotEmpty) {
      throw Exception('You already have an active reservation or borrow for this book.');
    }

    // 2. Check available copies
    final bookData = await _client
        .from('books')
        .select('id, title, available_copies, total_copies')
        .eq('id', bookId)
        .single();

    final availableCopies = (bookData['available_copies'] as num?)?.toInt() ?? 0;
    if (availableCopies <= 0) {
      throw Exception('No copies of this book are currently available to reserve.');
    }

    // 3. Decrement available copies
    await _client.from('books').update({
      'available_copies': availableCopies - 1,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookId);

    // 4. Create reservation record
    final qrToken = generateQrToken();
    final now = DateTime.now();
    final res = await _client
        .from('book_reservations')
        .insert({
          'book_id': bookId,
          'user_id': userId,
          'status': 'reserved',
          'qr_token': qrToken,
          'reserved_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        })
        .select('*, books(*)')
        .single();

    // 5. Notify the student
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': 'Book Hold Confirmed 📚',
        'body':
            'Your copy of "${bookData['title']}" is held. Visit the library front desk to pick it up.',
        'type': 'booking_confirmed',
      });
    } catch (_) {}

    return BookReservation.fromMap(res);
  }

  /// Get all reservations / borrows for a student.
  Future<List<BookReservation>> getStudentReservations(String userId) async {
    final data = await _client
        .from('book_reservations')
        .select('*, books(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => BookReservation.fromMap(e)).toList();
  }

  /// Get all reservations across all students (Librarian view).
  Future<List<BookReservation>> getAllReservations({
    BookReservationStatus? status,
  }) async {
    var query = _client
        .from('book_reservations')
        .select('*, books(*), profiles(full_name, student_staff_id, email)');

    if (status != null) {
      final data = await _client
          .from('book_reservations')
          .select('*, books(*), profiles(full_name, student_staff_id, email)')
          .eq('status', status.dbValue)
          .order('created_at', ascending: false);
      return (data as List).map((e) => BookReservation.fromMap(e)).toList();
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => BookReservation.fromMap(e)).toList();
  }

  /// Look up a reservation by QR token.
  Future<BookReservation?> getReservationByQrToken(String token) async {
    final data = await _client
        .from('book_reservations')
        .select('*, books(*), profiles(full_name, student_staff_id, email)')
        .eq('qr_token', token)
        .maybeSingle();
    if (data == null) return null;
    return BookReservation.fromMap(data);
  }

  /// Librarian marks a reserved book as borrowed (issued to student).
  Future<void> markAsBorrowed(String reservationId, {DateTime? dueDate}) async {
    final res = await _client
        .from('book_reservations')
        .select('*, books(title)')
        .eq('id', reservationId)
        .single();

    final now = DateTime.now();
    final due = dueDate ?? now.add(const Duration(days: 14));

    await _client.from('book_reservations').update({
      'status': 'borrowed',
      'borrowed_at': now.toIso8601String(),
      'due_date': due.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }).eq('id', reservationId);

    // Notify student
    final bookTitle = res['books'] != null ? res['books']['title'] : 'book';
    final dueStr = '${due.day}/${due.month}/${due.year}';
    try {
      await _client.from('notifications').insert({
        'user_id': res['user_id'],
        'title': 'Book Borrowed ✓',
        'body': 'You have checked out "$bookTitle". Due date is $dueStr.',
        'type': 'booking_checkin',
      });
    } catch (_) {}
  }

  /// Librarian marks a borrowed book as returned.
  /// Increments available copies for the book.
  Future<void> markAsReturned(String reservationId) async {
    final res = await _client
        .from('book_reservations')
        .select('*, books(id, title, total_copies, available_copies)')
        .eq('id', reservationId)
        .single();

    final now = DateTime.now();
    await _client.from('book_reservations').update({
      'status': 'returned',
      'returned_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }).eq('id', reservationId);

    // Increment available copies
    final book = res['books'];
    if (book != null) {
      final currentAvail = (book['available_copies'] as num?)?.toInt() ?? 0;
      final total = (book['total_copies'] as num?)?.toInt() ?? currentAvail + 1;
      final newAvail = (currentAvail + 1).clamp(0, total);
      await _client.from('books').update({
        'available_copies': newAvail,
        'updated_at': now.toIso8601String(),
      }).eq('id', book['id']);
    }

    // Notify student
    try {
      await _client.from('notifications').insert({
        'user_id': res['user_id'],
        'title': 'Book Returned 📖',
        'body': 'Your copy of "${book?['title'] ?? 'book'}" has been successfully returned.',
        'type': 'info',
      });
    } catch (_) {}
  }

  /// Cancel a book reservation. Restores available copies if it was in 'reserved' status.
  Future<void> cancelReservation(
    String reservationId, {
    String? reason,
    String? cancelledBy,
  }) async {
    final res = await _client
        .from('book_reservations')
        .select('*, books(id, title, total_copies, available_copies)')
        .eq('id', reservationId)
        .single();

    final currentStatus = res['status'] as String;
    if (currentStatus == 'returned' || currentStatus == 'cancelled') return;

    final now = DateTime.now();
    await _client.from('book_reservations').update({
      'status': 'cancelled',
      'cancelled_at': now.toIso8601String(),
      'cancellation_reason': reason ?? 'Cancelled by ${cancelledBy ?? "student"}',
      'updated_at': now.toIso8601String(),
    }).eq('id', reservationId);

    // If hold was cancelled, release copy back to shelf
    if (currentStatus == 'reserved') {
      final book = res['books'];
      if (book != null) {
        final currentAvail = (book['available_copies'] as num?)?.toInt() ?? 0;
        final total = (book['total_copies'] as num?)?.toInt() ?? currentAvail + 1;
        final newAvail = (currentAvail + 1).clamp(0, total);
        await _client.from('books').update({
          'available_copies': newAvail,
          'updated_at': now.toIso8601String(),
        }).eq('id', book['id']);
      }
    }

    // Notify student
    try {
      await _client.from('notifications').insert({
        'user_id': res['user_id'],
        'title': 'Hold Cancelled',
        'body': 'Reservation for "${res['books']?['title'] ?? 'book'}" was cancelled.',
        'type': 'booking_cancelled',
      });
    } catch (_) {}
  }

  /// Check whether a user already holds or has borrowed a book.
  Future<bool> hasActiveHoldOrBorrow(String userId, String bookId) async {
    final data = await _client
        .from('book_reservations')
        .select('id')
        .eq('book_id', bookId)
        .eq('user_id', userId)
        .inFilter('status', ['reserved', 'borrowed'])
        .limit(1);
    return (data as List).isNotEmpty;
  }
}
