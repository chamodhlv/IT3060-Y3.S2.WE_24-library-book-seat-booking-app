import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seat_model.dart';

/// Service for seats, bookings, and notifications.
class SeatService {
  static final SeatService _instance = SeatService._internal();
  factory SeatService() => _instance;
  SeatService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // ─── SEATS ───────────────────────────────────────────────────

  /// Seed default seats if the seats table is currently empty.
  Future<void> seedDefaultSeatsIfEmpty() async {
    try {
      final existing = await _client.from('seats').select('id').limit(1);
      if ((existing as List).isNotEmpty) return;

      final List<Map<String, dynamic>> defaultSeats = [];
      int sort = 1;

      // Main hall seats A1..A5, B1..B5, C1..C5, D1..D5
      for (final row in ['A', 'B', 'C', 'D']) {
        for (int col = 1; col <= 5; col++) {
          final label = '$row$col';
          final features = <String>['individual_study_seat'];
          if (row == 'A') features.add('window_side');
          if (col == 5 || row == 'C') features.add('power_outlet');

          defaultSeats.add({
            'label': label,
            'section': 'main_hall',
            'capacity': 1,
            'features': features,
            'description': row == 'A' ? 'Window side individual seat' : 'Quiet study desk',
            'is_active': true,
            'sort_order': sort++,
          });
        }
      }

      // Group pods Pod 1..Pod 4
      for (int p = 1; p <= 4; p++) {
        defaultSeats.add({
          'label': 'Pod $p',
          'section': 'group_pods',
          'capacity': 5,
          'features': ['group_study', 'whiteboard', 'power_outlet'],
          'description': 'Group study pod for up to 5 people with whiteboard',
          'is_active': true,
          'sort_order': sort++,
        });
      }

      await _client.from('seats').insert(defaultSeats);
    } catch (_) {
      // Ignore errors if table schema not ready
    }
  }

  /// Fetch all active seats in a section.
  Future<List<Seat>> getSeats({SeatSection? section}) async {
    await seedDefaultSeatsIfEmpty();
    if (section != null) {
      final data = await _client
          .from('seats')
          .select()
          .eq('is_active', true)
          .eq('section', section.dbValue)
          .order('sort_order');
      return (data as List).map((e) => Seat.fromMap(e)).toList();
    }

    final data = await _client
        .from('seats')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return (data as List).map((e) => Seat.fromMap(e)).toList();
  }

  /// Fetch all seats (including inactive) for librarian management.
  Future<List<Seat>> getAllSeats({SeatSection? section}) async {
    await seedDefaultSeatsIfEmpty();
    if (section != null) {
      final data = await _client
          .from('seats')
          .select()
          .eq('section', section.dbValue)
          .order('sort_order');
      return (data as List).map((e) => Seat.fromMap(e)).toList();
    }
    final data = await _client
        .from('seats')
        .select()
        .order('sort_order');
    return (data as List).map((e) => Seat.fromMap(e)).toList();
  }

  /// Add a new seat.
  Future<Seat> addSeat(Seat seat) async {
    final data = await _client
        .from('seats')
        .insert(seat.toMap())
        .select()
        .single();
    return Seat.fromMap(data);
  }

  /// Update an existing seat.
  Future<void> updateSeat(String seatId, Seat seat) async {
    await _client.from('seats').update({
      ...seat.toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', seatId);
  }

  /// Delete a seat (and cascade bookings).
  Future<void> deleteSeat(String seatId) async {
    await _client.from('seats').delete().eq('id', seatId);
  }

  // ─── BOOKINGS ────────────────────────────────────────────────

  /// Get all confirmed/checked-in bookings for a seat on a date.
  Future<List<SeatBooking>> getBookingsForSeatOnDate(
      String seatId, DateTime date) async {
    final dateStr = _dateStr(date);
    final data = await _client
        .from('seat_bookings')
        .select('*, seats(*), profiles(full_name, student_staff_id)')
        .eq('seat_id', seatId)
        .eq('date', dateStr)
        .inFilter('status', ['confirmed', 'checked_in'])
        .order('start_hour');
    return (data as List).map((e) => SeatBooking.fromMap(e)).toList();
  }

  /// Returns which hours [8..17] are already booked for a seat on a date.
  Future<Set<int>> getBookedHours(String seatId, DateTime date) async {
    final bookings = await getBookingsForSeatOnDate(seatId, date);
    final Set<int> booked = {};
    for (final b in bookings) {
      for (int h = b.startHour; h < b.endHour; h++) {
        booked.add(h);
      }
    }
    return booked;
  }

  /// Returns whether a seat has ANY available future slots today or in the next 4 days.
  Future<bool> seatHasAvailability(String seatId) async {
    final now = DateTime.now();
    for (int d = 0; d < 4; d++) {
      final date = now.add(Duration(days: d));
      final booked = await getBookedHours(seatId, date);
      // Operating hours: 8-17 = 9 slots
      int unbookableCount = 0;
      for (int h = 8; h < 17; h++) {
        final slotStart = DateTime(date.year, date.month, date.day, h);
        if (booked.contains(h) || slotStart.isBefore(now)) {
          unbookableCount++;
        }
      }
      if (unbookableCount < 9) return true;
    }
    return false;
  }

  /// Get availability status for ALL seats on a given date.
  /// Returns map of seatId -> available (true) or fully booked (false).
  Future<Map<String, bool>> getSeatAvailabilityForDate(DateTime date) async {
    final dateStr = _dateStr(date);
    // Get all bookings on this date
    final data = await _client
        .from('seat_bookings')
        .select('seat_id, start_hour, end_hour')
        .eq('date', dateStr)
        .inFilter('status', ['confirmed', 'checked_in']);

    // Build a map seatId -> set of booked hours
    final Map<String, Set<int>> bookedHoursMap = {};
    for (final row in (data as List)) {
      final seatId = row['seat_id'] as String;
      final startH = (row['start_hour'] as num).toInt();
      final endH = (row['end_hour'] as num).toInt();
      bookedHoursMap.putIfAbsent(seatId, () => {});
      for (int h = startH; h < endH; h++) {
        bookedHoursMap[seatId]!.add(h);
      }
    }

    // Get all active seats
    final seats = await getSeats();
    final Map<String, bool> result = {};
    final now = DateTime.now();
    for (final seat in seats) {
      final booked = bookedHoursMap[seat.id] ?? {};
      int unbookableCount = 0;
      for (int h = 8; h < 17; h++) {
        final slotStart = DateTime(date.year, date.month, date.day, h);
        if (booked.contains(h) || slotStart.isBefore(now)) {
          unbookableCount++;
        }
      }
      result[seat.id] = unbookableCount < 9; // true = has available future slots
    }
    return result;
  }

  /// Create a booking. Returns the created booking.
  Future<SeatBooking> createBooking({
    required String seatId,
    required String userId,
    required DateTime date,
    required int startHour,
    required int endHour,
    bool reminderEnabled = false,
  }) async {
    final now = DateTime.now();
    final slotStart = DateTime(date.year, date.month, date.day, startHour);
    if (slotStart.isBefore(now)) {
      throw Exception('Cannot book a time slot in the past.');
    }

    final qrToken = generateQrToken();
    final data = await _client
        .from('seat_bookings')
        .insert({
          'seat_id': seatId,
          'user_id': userId,
          'date': _dateStr(date),
          'start_hour': startHour,
          'end_hour': endHour,
          'status': 'confirmed',
          'qr_token': qrToken,
          'reminder_enabled': reminderEnabled,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, seats(*)')
        .single();
    return SeatBooking.fromMap(data);
  }

  /// Get a student's bookings (with seat info).
  Future<List<SeatBooking>> getStudentBookings(String userId) async {
    final data = await _client
        .from('seat_bookings')
        .select('*, seats(*)')
        .eq('user_id', userId)
        .order('date', ascending: false)
        .order('start_hour', ascending: false);
    return (data as List).map((e) => SeatBooking.fromMap(e)).toList();
  }

  /// Get ALL bookings (librarian view) with user info.
  Future<List<SeatBooking>> getAllBookings({
    DateTime? date,
    BookingStatus? status,
  }) async {
    var query = _client
        .from('seat_bookings')
        .select('*, seats(*), profiles(full_name, student_staff_id)');

    if (date != null) {
      final data = await _client
          .from('seat_bookings')
          .select('*, seats(*), profiles(full_name, student_staff_id)')
          .eq('date', _dateStr(date))
          .order('date', ascending: false)
          .order('start_hour');
      return (data as List).map((e) => SeatBooking.fromMap(e)).toList();
    }

    if (status != null) {
      final data = await _client
          .from('seat_bookings')
          .select('*, seats(*), profiles(full_name, student_staff_id)')
          .eq('status', status.dbValue)
          .order('date', ascending: false)
          .order('start_hour');
      return (data as List).map((e) => SeatBooking.fromMap(e)).toList();
    }

    final data = await query
        .order('date', ascending: false)
        .order('start_hour');
    return (data as List).map((e) => SeatBooking.fromMap(e)).toList();
  }

  /// Find a booking by QR token.
  Future<SeatBooking?> getBookingByQrToken(String token) async {
    final data = await _client
        .from('seat_bookings')
        .select('*, seats(*), profiles(full_name, student_staff_id)')
        .eq('qr_token', token)
        .maybeSingle();
    if (data == null) return null;
    return SeatBooking.fromMap(data);
  }

  /// Check in a booking (librarian).
  Future<void> checkIn(String bookingId) async {
    await _client.from('seat_bookings').update({
      'status': 'checked_in',
      'check_in_time': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Cancel a booking.
  Future<void> cancelBooking(
      String bookingId, {
      String? reason,
      String? cancelledBy,
    }) async {
    await _client.from('seat_bookings').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'cancelled_by': cancelledBy ?? 'student',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Expire bookings where 15-minute check-in window has passed.
  /// Call this when loading the bookings screen.
  Future<void> expireOldBookings() async {
    // Find confirmed bookings where auto-release time has passed
    final now = DateTime.now();
    final todayStr = _dateStr(now);
    // Auto-release = startHour * 60 + 15 minutes (in minutes since midnight)
    final currentMinutes = now.hour * 60 + now.minute;

    // We fetch today's confirmed bookings and check locally
    final data = await _client
        .from('seat_bookings')
        .select()
        .eq('date', todayStr)
        .eq('status', 'confirmed');

    final List<String> toExpire = [];
    for (final row in (data as List)) {
      final startHour = (row['start_hour'] as num).toInt();
      final autoReleaseMinutes = startHour * 60 + 15;
      if (currentMinutes > autoReleaseMinutes) {
        toExpire.add(row['id'] as String);
      }
    }

    if (toExpire.isNotEmpty) {
      await _client
          .from('seat_bookings')
          .update({
            'status': 'no_show',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .inFilter('id', toExpire);
    }
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────────

  /// Get notifications for a user.
  Future<List<AppNotification>> getNotifications(String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => AppNotification.fromMap(e)).toList();
  }

  /// Create a notification for a user.
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedBookingId,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'related_booking_id': relatedBookingId,
    });
  }

  /// Mark a notification as read.
  Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications for a user as read.
  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Unread count for a user.
  Future<int> getUnreadCount(String userId) async {
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }

  // ─── Helpers ──────────────────────────────────────────────────

  String _dateStr(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
