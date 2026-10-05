/// Represents a book in the library catalogue.
class Book {
  final String id;
  final String title;
  final String authors; // comma-separated author names
  final String? isbn;
  final String? publisher;
  final int? publishedYear;
  final String? genre;
  final String? description;
  final String? shelfLocation; // e.g. "Shelf A1", "Shelf C4"
  final int totalCopies;
  final int availableCopies;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Book({
    required this.id,
    required this.title,
    required this.authors,
    this.isbn,
    this.publisher,
    this.publishedYear,
    this.genre,
    this.description,
    this.shelfLocation,
    required this.totalCopies,
    required this.availableCopies,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  /// Initials to show on the avatar chip (up to 2 chars from title words).
  String get initials {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return title.substring(0, title.length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Whether at least one copy is available.
  bool get hasAvailableCopy => availableCopies > 0;

  /// Copies status label.
  String get copiesLabel {
    if (availableCopies == 0) return 'No copies available';
    if (availableCopies == 1) return '1 copy';
    return '$availableCopies copies';
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      authors: map['authors'] as String? ?? '',
      isbn: map['isbn'] as String?,
      publisher: map['publisher'] as String?,
      publishedYear: map['published_year'] as int?,
      genre: map['genre'] as String?,
      description: map['description'] as String?,
      shelfLocation: map['shelf_location'] as String?,
      totalCopies: (map['total_copies'] as int?) ?? 1,
      availableCopies: (map['available_copies'] as int?) ?? 1,
      isActive: (map['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'title': title,
      'authors': authors,
      if (isbn != null) 'isbn': isbn,
      if (publisher != null) 'publisher': publisher,
      if (publishedYear != null) 'published_year': publishedYear,
      if (genre != null) 'genre': genre,
      if (description != null) 'description': description,
      if (shelfLocation != null) 'shelf_location': shelfLocation,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'is_active': isActive,
    };
  }

  Book copyWith({
    String? title,
    String? authors,
    String? isbn,
    String? publisher,
    int? publishedYear,
    String? genre,
    String? description,
    String? shelfLocation,
    int? totalCopies,
    int? availableCopies,
    bool? isActive,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      isbn: isbn ?? this.isbn,
      publisher: publisher ?? this.publisher,
      publishedYear: publishedYear ?? this.publishedYear,
      genre: genre ?? this.genre,
      description: description ?? this.description,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
