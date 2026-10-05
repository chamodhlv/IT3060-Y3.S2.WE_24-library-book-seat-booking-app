import 'package:flutter_test/flutter_test.dart';
import 'package:libraryplus/models/book_reservation_model.dart';

void main() {
  group('BookReservation Model Tests', () {
    test('BookReservationStatus mapping and string parsing', () {
      expect(BookReservationStatus.fromString('reserved'), BookReservationStatus.reserved);
      expect(BookReservationStatus.fromString('borrowed'), BookReservationStatus.borrowed);
      expect(BookReservationStatus.fromString('returned'), BookReservationStatus.returned);
      expect(BookReservationStatus.fromString('cancelled'), BookReservationStatus.cancelled);
      expect(BookReservationStatus.fromString('unknown'), BookReservationStatus.reserved);

      expect(BookReservationStatus.reserved.dbValue, 'reserved');
      expect(BookReservationStatus.borrowed.dbValue, 'borrowed');
      expect(BookReservationStatus.returned.dbValue, 'returned');
      expect(BookReservationStatus.cancelled.dbValue, 'cancelled');
    });

    test('BookReservation fromMap and toMap roundtrip', () {
      final now = DateTime.now();
      final map = {
        'id': 'res-123',
        'book_id': 'book-456',
        'user_id': 'user-789',
        'status': 'reserved',
        'qr_token': 'token-abc',
        'reserved_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'books': {
          'id': 'book-456',
          'title': 'Clean Code',
          'authors': 'Robert C. Martin',
          'total_copies': 3,
          'available_copies': 2,
          'is_active': true,
          'created_at': now.toIso8601String(),
        },
        'profiles': {
          'full_name': 'John Doe',
          'student_staff_id': 'STU1001',
          'email': 'john@example.com',
        },
      };

      final reservation = BookReservation.fromMap(map);

      expect(reservation.id, 'res-123');
      expect(reservation.bookId, 'book-456');
      expect(reservation.userId, 'user-789');
      expect(reservation.status, BookReservationStatus.reserved);
      expect(reservation.isReserved, isTrue);
      expect(reservation.isBorrowed, isFalse);
      expect(reservation.book?.title, 'Clean Code');
      expect(reservation.userFullName, 'John Doe');
      expect(reservation.userStudentId, 'STU1001');

      final toMapResult = reservation.toMap();
      expect(toMapResult['book_id'], 'book-456');
      expect(toMapResult['user_id'], 'user-789');
      expect(toMapResult['status'], 'reserved');
      expect(toMapResult['qr_token'], 'token-abc');
    });

    test('hold expiration and overdue checks', () {
      final now = DateTime.now();
      final futureDue = now.add(const Duration(days: 7));
      final pastDue = now.subtract(const Duration(days: 1));

      final activeBorrow = BookReservation(
        id: '1',
        bookId: 'b1',
        userId: 'u1',
        status: BookReservationStatus.borrowed,
        reservedAt: now.subtract(const Duration(days: 2)),
        borrowedAt: now.subtract(const Duration(days: 1)),
        dueDate: futureDue,
        createdAt: now,
      );
      expect(activeBorrow.isOverdue, isFalse);

      final overdueBorrow = activeBorrow.copyWith(dueDate: pastDue);
      expect(overdueBorrow.isOverdue, isTrue);

      final hold = BookReservation(
        id: '2',
        bookId: 'b2',
        userId: 'u2',
        status: BookReservationStatus.reserved,
        reservedAt: now,
        createdAt: now,
      );
      expect(hold.isHoldExpired, isFalse);
      expect(hold.holdExpiresAt.difference(now).inDays, 3);
    });
  });
}
