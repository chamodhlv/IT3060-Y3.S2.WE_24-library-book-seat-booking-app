/// Represents user roles in the app.
enum UserRole {
  student,
  librarian;

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.librarian:
        return 'Librarian';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'librarian':
        return UserRole.librarian;
      default:
        return UserRole.student;
    }
  }
}

/// App user model.
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String studentStaffId;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.studentStaffId,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String? ?? '',
      studentStaffId: map['student_staff_id'] as String? ?? '',
      role: UserRole.fromString(map['role'] as String? ?? 'student'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'student_staff_id': studentStaffId,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? studentStaffId,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      studentStaffId: studentStaffId ?? this.studentStaffId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns initials from the full name (up to 2 characters).
  String get initials {
    if (fullName.isEmpty) return '?';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Returns a masked version of the student/staff ID.
  String get maskedId {
    if (studentStaffId.length <= 6) return studentStaffId;
    return '${studentStaffId.substring(0, 6)}xxxxx';
  }
}
