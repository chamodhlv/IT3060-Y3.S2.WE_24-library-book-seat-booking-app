import 'dart:math';

/// Represents the section of a seat.
enum SeatSection {
  mainHall,
  groupPods;

  String get displayName {
    switch (this) {
      case SeatSection.mainHall:
        return 'Main Hall';
      case SeatSection.groupPods:
        return 'Group Pods';
    }
  }

  String get dbValue {
    switch (this) {
      case SeatSection.mainHall:
        return 'main_hall';
      case SeatSection.groupPods:
        return 'group_pods';
    }
  }

  static SeatSection fromString(String value) {
    switch (value) {
      case 'group_pods':
        return SeatSection.groupPods;
      default:
        return SeatSection.mainHall;
    }
  }
}

/// A library seat.
class Seat {
  final String id;
  final String label;
  final SeatSection section;
  final String? description;
  final int capacity;
  final List<String> features;
  final bool isActive;
  final int sortOrder;

  const Seat({
    required this.id,
    required this.label,
    required this.section,
    this.description,
    required this.capacity,
    required this.features,
    required this.isActive,
    required this.sortOrder,
  });

  factory Seat.fromMap(Map<String, dynamic> map) {
    return Seat(
      id: map['id'] as String,
      label: map['label'] as String,
      section: SeatSection.fromString(map['section'] as String? ?? 'main_hall'),
      description: map['description'] as String?,
      capacity: (map['capacity'] as num?)?.toInt() ?? 1,
      features: (map['features'] as List?)?.cast<String>() ?? [],
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'section': section.dbValue,
        'description': description,
        'capacity': capacity,
        'features': features,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  /// Returns a human-readable features string.
  String get featuresDisplay {
    final map = {
      'window_side': 'Window side',
      'power_outlet': 'Power outlet nearby',
      'individual_study_seat': 'Individual study seat',
      'group_study': 'Group study',
      'whiteboard': 'Whiteboard',
    };
    return features.map((f) => map[f] ?? f).join(' · ');
  }

  Seat copyWith({
    String? id,
    String? label,
    SeatSection? section,
    String? description,
    int? capacity,
    List<String>? features,
    bool? isActive,
    int? sortOrder,
  }) {
    return Seat(
      id: id ?? this.id,
      label: label ?? this.label,
      section: section ?? this.section,
      description: description ?? this.description,
      capacity: capacity ?? this.capacity,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Booking status.
enum BookingStatus {
  confirmed,
  checkedIn,
  cancelled,
  expired,
  noShow;

  String get dbValue {
    switch (this) {
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.checkedIn:
        return 'checked_in';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.expired:
        return 'expired';
      case BookingStatus.noShow:
        return 'no_show';
    }
  }

  String get displayName {
    switch (this) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.checkedIn:
        return 'Checked In';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.expired:
        return 'Expired';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  static BookingStatus fromString(String value) {
    switch (value) {
      case 'checked_in':
        return BookingStatus.checkedIn;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'expired':
        return BookingStatus.expired;
      case 'no_show':
        return BookingStatus.noShow;
      default:
        return BookingStatus.confirmed;
    }
  }
}

/// A seat booking.
class SeatBooking {
  final String id;
  final String seatId;
  final String userId;
  final DateTime date;
  final int startHour;
  final int endHour;
  final BookingStatus status;
  final String? qrToken;
  final DateTime? checkInTime;
  final String? cancellationReason;
  final String? cancelledBy;
  final bool reminderEnabled;
  final DateTime createdAt;

  // Joined data (optional — loaded with seat info)
  final Seat? seat;
  final String? userFullName;
  final String? userStudentId;

  const SeatBooking({
    required this.id,
    required this.seatId,
    required this.userId,
    required this.date,
    required this.startHour,
    required this.endHour,
    required this.status,
    this.qrToken,
    this.checkInTime,
    this.cancellationReason,
    this.cancelledBy,
    required this.reminderEnabled,
    required this.createdAt,
    this.seat,
    this.userFullName,
    this.userStudentId,
  });

  factory SeatBooking.fromMap(Map<String, dynamic> map) {
    Seat? seat;
    if (map['seats'] != null) {
      seat = Seat.fromMap(map['seats'] as Map<String, dynamic>);
    }

    String? userName;
    String? userStudentId;
    if (map['profiles'] != null) {
      final p = map['profiles'] as Map<String, dynamic>;
      userName = p['full_name'] as String?;
      userStudentId = p['student_staff_id'] as String?;
    }

    return SeatBooking(
      id: map['id'] as String,
      seatId: map['seat_id'] as String,
      userId: map['user_id'] as String,
      date: DateTime.parse(map['date'] as String),
      startHour: (map['start_hour'] as num).toInt(),
      endHour: (map['end_hour'] as num).toInt(),
      status: BookingStatus.fromString(map['status'] as String? ?? 'confirmed'),
      qrToken: map['qr_token'] as String?,
      checkInTime: map['check_in_time'] != null
          ? DateTime.parse(map['check_in_time'] as String)
          : null,
      cancellationReason: map['cancellation_reason'] as String?,
      cancelledBy: map['cancelled_by'] as String?,
      reminderEnabled: map['reminder_enabled'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      seat: seat,
      userFullName: userName,
      userStudentId: userStudentId,
    );
  }

  /// e.g. "2:00 PM – 4:00 PM"
  String get timeRangeDisplay {
    return '${_formatHour(startHour)} – ${_formatHour(endHour)}';
  }

  String _formatHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }

  /// Duration in hours.
  int get durationHours => endHour - startHour;

  /// Auto-release deadline: 15 minutes after start.
  DateTime get autoReleaseTime {
    return DateTime(date.year, date.month, date.day, startHour, 15);
  }

  /// Check-in window opens 15 min before start.
  DateTime get checkInWindowStart {
    final dt = DateTime(date.year, date.month, date.day, startHour);
    return dt.subtract(const Duration(minutes: 15));
  }

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  bool get isUpcoming {
    final now = DateTime.now();
    final startDt = DateTime(date.year, date.month, date.day, startHour);
    return startDt.isAfter(now) &&
        (status == BookingStatus.confirmed || status == BookingStatus.checkedIn);
  }

  bool get isPast {
    final now = DateTime.now();
    final endDt = DateTime(date.year, date.month, date.day, endHour);
    return endDt.isBefore(now);
  }
}

/// An in-app notification.
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? relatedBookingId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.relatedBookingId,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] as String? ?? 'info',
      isRead: map['is_read'] as bool? ?? false,
      relatedBookingId: map['related_booking_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Helper to generate a UUID v4 token for QR codes.
String generateQrToken() {
  final rand = Random.secure();
  final values = List<int>.generate(16, (_) => rand.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}
