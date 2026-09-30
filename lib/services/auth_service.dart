import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Helper function to generate a random UUID v4 in pure Dart.
String generateUuid() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40; // version 4
  values[8] = (values[8] & 0x3f) | 0x80; // variant 10
  final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

/// Service layer for custom direct database authentication and user management.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  static const String _userSessionKey = 'libraryplus_active_user_id';

  AppUser? _currentUser;

  /// Current logged in user.
  AppUser? get currentUser => _currentUser;

  /// Initialize and load saved session from local storage.
  Future<AppUser?> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString(_userSessionKey);
    if (savedUserId != null && savedUserId.isNotEmpty) {
      try {
        final data = await _client
            .from('profiles')
            .select()
            .eq('id', savedUserId)
            .maybeSingle();

        if (data != null) {
          _currentUser = AppUser.fromMap(data);
          return _currentUser;
        }
      } catch (_) {
        // If query fails, fallback to null
      }
    }
    _currentUser = null;
    return null;
  }

  // ─── Authentication ────────────────────────────────────────────

  /// Sign up directly using the database `profiles` table.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required String studentStaffId,
    UserRole role = UserRole.student,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    // Check if email already exists
    final existing = await _client
        .from('profiles')
        .select()
        .eq('email', trimmedEmail)
        .maybeSingle();

    if (existing != null) {
      throw Exception('An account with this email already exists.');
    }

    final id = generateUuid();
    final profile = {
      'id': id,
      'email': trimmedEmail,
      'password': password,
      'full_name': fullName,
      'student_staff_id': studentStaffId,
      'role': role.name,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('profiles').insert(profile);

    _currentUser = AppUser.fromMap(profile);
    await _saveUserSession(id);
    return _currentUser!;
  }

  /// Sign in directly using credentials in the `profiles` table.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    final data = await _client
        .from('profiles')
        .select()
        .eq('email', trimmedEmail)
        .maybeSingle();

    if (data == null) {
      throw Exception('No account found with this email.');
    }

    if (data['password'] != password) {
      throw Exception('Incorrect password.');
    }

    _currentUser = AppUser.fromMap(data);
    await _saveUserSession(_currentUser!.id);
    return _currentUser!;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSessionKey);
  }

  // ─── Profile Management ────────────────────────────────────────

  /// Get the profile of the currently signed-in user.
  Future<AppUser> getCurrentUserProfile() async {
    if (_currentUser == null) throw Exception('No user is signed in.');

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', _currentUser!.id)
        .single();

    _currentUser = AppUser.fromMap(data);
    return _currentUser!;
  }

  /// Update the current user's profile.
  Future<AppUser> updateProfile({
    required String fullName,
    required String studentStaffId,
  }) async {
    if (_currentUser == null) throw Exception('No user is signed in.');

    await _client.from('profiles').update({
      'full_name': fullName,
      'student_staff_id': studentStaffId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', _currentUser!.id);

    return await getCurrentUserProfile();
  }

  /// Update the current user's email.
  Future<void> updateEmail(String newEmail) async {
    if (_currentUser == null) throw Exception('No user is signed in.');
    final trimmedEmail = newEmail.trim().toLowerCase();

    await _client.from('profiles').update({
      'email': trimmedEmail,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', _currentUser!.id);

    _currentUser = _currentUser!.copyWith(email: trimmedEmail);
  }

  /// Update the current user's password.
  Future<void> updatePassword(String newPassword) async {
    if (_currentUser == null) throw Exception('No user is signed in.');

    await _client.from('profiles').update({
      'password': newPassword,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', _currentUser!.id);
  }

  /// Delete the current user's account.
  Future<void> deleteAccount() async {
    if (_currentUser == null) throw Exception('No user is signed in.');

    await _client.from('profiles').delete().eq('id', _currentUser!.id);
    await signOut();
  }

  // ─── Admin / Librarian Operations ──────────────────────────────

  /// Get all users (librarian view).
  Future<List<AppUser>> getAllUsers() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    return (data as List).map((e) => AppUser.fromMap(e)).toList();
  }

  /// Search users by name, email, or ID.
  Future<List<AppUser>> searchUsers(String query) async {
    final data = await _client
        .from('profiles')
        .select()
        .or('full_name.ilike.%$query%,email.ilike.%$query%,student_staff_id.ilike.%$query%')
        .order('created_at', ascending: false);

    return (data as List).map((e) => AppUser.fromMap(e)).toList();
  }

  /// Update a user's role.
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    await _client.from('profiles').update({
      'role': newRole.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Update any user's profile.
  Future<void> updateUserProfile({
    required String userId,
    required String fullName,
    required String studentStaffId,
    required String email,
    required UserRole role,
  }) async {
    await _client.from('profiles').update({
      'full_name': fullName,
      'student_staff_id': studentStaffId,
      'email': email.trim().toLowerCase(),
      'role': role.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Delete a user's profile.
  Future<void> deleteUserProfile(String userId) async {
    await _client.from('profiles').delete().eq('id', userId);
  }

  // ─── Local Session Helper ──────────────────────────────────────

  Future<void> _saveUserSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userSessionKey, userId);
  }
}
