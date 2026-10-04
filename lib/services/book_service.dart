import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book_model.dart';

/// Service for library book CRUD operations.
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
}
