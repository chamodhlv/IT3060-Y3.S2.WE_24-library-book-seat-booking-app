import 'book_model.dart';

/// Status of a book reservation / borrowing lifecycle.
enum BookReservationStatus {
  reserved,
  borrowed,
  returned,
  cancelled;

  String get dbValue {
    switch (this) {
      case BookReservationStatus.reserved:
        return 'reserved';
      case BookReservationStatus.borrowed:
        return 'borrowed';
      case BookReservationStatus.returned:
        return 'returned';
      case BookReservationStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayName {
    switch (this) {
      case BookReservationStatus.reserved:
        return 'Reserved (Hold)';
      case BookReservationStatus.borrowed:
        return 'Borrowed';
      case BookReservationStatus.returned:
        return 'Returned';
      case BookReservationStatus.cancelled:
        return 'Cancelled';
    }
  }

  static BookReservationStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'borrowed':
        return BookReservationStatus.borrowed;
      case 'returned':
        return BookReservationStatus.returned;
      case 'cancelled':
        return BookReservationStatus.cancelled;
      default:
        return BookReservationStatus.reserved;
    }
  }
}

/// Represents a student book reservation or borrow record.
class BookReservation {
  final String id;
  final String bookId;
  final String userId;
  final BookReservationStatus status;
  final String? qrToken;
  final DateTime reservedAt;
  final DateTime? borrowedAt;
  final DateTime? dueDate;
  final DateTime? returnedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined metadata
  final Book? book;
  final String? userFullName;
  final String? userStudentId;
  final String? userEmail;

  const BookReservation({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.status,
    this.qrToken,
    required this.reservedAt,
    this.borrowedAt,
    this.dueDate,
    this.returnedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.book,
    this.userFullName,
    this.userStudentId,
    this.userEmail,
  });

  bool get isReserved => status == BookReservationStatus.reserved;
  bool get isBorrowed => status == BookReservationStatus.borrowed;
  bool get isReturned => status == BookReservationStatus.returned;
  bool get isCancelled => status == BookReservationStatus.cancelled;

  /// Hold expires 3 days after reservation if not picked up.
  DateTime get holdExpiresAt => reservedAt.add(const Duration(days: 3));

  /// Check whether hold has expired.
  bool get isHoldExpired =>
      isReserved && DateTime.now().isAfter(holdExpiresAt);

  /// Whether this reservation can currently be picked up at the desk.
  bool get isPickupAvailable => isReserved && !isHoldExpired;

  /// Check whether borrowed book is overdue.
  bool get isOverdue {
    if (!isBorrowed || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  factory BookReservation.fromMap(Map<String, dynamic> map) {
    Book? book;
    if (map['books'] != null && map['books'] is Map<String, dynamic>) {
      book = Book.fromMap(map['books'] as Map<String, dynamic>);
    }

    String? userName;
    String? userStudentId;
    String? userEmail;
    if (map['profiles'] != null && map['profiles'] is Map<String, dynamic>) {
      final p = map['profiles'] as Map<String, dynamic>;
      userName = p['full_name'] as String?;
      userStudentId = p['student_staff_id'] as String?;
      userEmail = p['email'] as String?;
    }

    return BookReservation(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      userId: map['user_id'] as String,
      status: BookReservationStatus.fromString(map['status'] as String? ?? 'reserved'),
      qrToken: map['qr_token'] as String?,
      reservedAt: map['reserved_at'] != null
          ? DateTime.parse(map['reserved_at'] as String)
          : (map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now()),
      borrowedAt: map['borrowed_at'] != null
          ? DateTime.parse(map['borrowed_at'] as String)
          : null,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      returnedAt: map['returned_at'] != null
          ? DateTime.parse(map['returned_at'] as String)
          : null,
      cancelledAt: map['cancelled_at'] != null
          ? DateTime.parse(map['cancelled_at'] as String)
          : null,
      cancellationReason: map['cancellation_reason'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      book: book,
      userFullName: userName,
      userStudentId: userStudentId,
      userEmail: userEmail,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'user_id': userId,
      'status': status.dbValue,
      'qr_token': qrToken,
      'reserved_at': reservedAt.toIso8601String(),
      if (borrowedAt != null) 'borrowed_at': borrowedAt!.toIso8601String(),
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (returnedAt != null) 'returned_at': returnedAt!.toIso8601String(),
      if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  BookReservation copyWith({
    String? id,
    String? bookId,
    String? userId,
    BookReservationStatus? status,
    String? qrToken,
    DateTime? reservedAt,
    DateTime? borrowedAt,
    DateTime? dueDate,
    DateTime? returnedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Book? book,
    String? userFullName,
    String? userStudentId,
    String? userEmail,
  }) {
    return BookReservation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      qrToken: qrToken ?? this.qrToken,
      reservedAt: reservedAt ?? this.reservedAt,
      borrowedAt: borrowedAt ?? this.borrowedAt,
      dueDate: dueDate ?? this.dueDate,
      returnedAt: returnedAt ?? this.returnedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      book: book ?? this.book,
      userFullName: userFullName ?? this.userFullName,
      userStudentId: userStudentId ?? this.userStudentId,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}
