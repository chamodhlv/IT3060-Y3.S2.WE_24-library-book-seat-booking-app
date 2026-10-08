import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/sign_in_screen.dart';
import 'user_management_screen.dart';
import 'librarian_seats_screen.dart';
import 'librarian_bookings_screen.dart';
import 'librarian_books_screen.dart';
import 'librarian_home_screen.dart';
import '../shared/notifications_screen.dart';

/// Librarian bottom navigation shell.
/// Same tabs as student but the last tab is "Users" instead of "Profile".
class LibrarianShell extends StatefulWidget {
  const LibrarianShell({super.key});

  @override
  State<LibrarianShell> createState() => _LibrarianShellState();
}

class _LibrarianShellState extends State<LibrarianShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    LibrarianHomeScreen(
      onNavigateTab: (index) => setState(() => _currentIndex = index),
      onSignOut: _signOut,
    ),
    const LibrarianSeatsScreen(),
    const LibrarianBookingsScreen(),
    const LibrarianBooksScreen(),
    const UserManagementScreen(),
  ];

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log out',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Log out',
                style: GoogleFonts.inter(
                    color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
      }
    }
  }

  String _getTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Seats';
      case 2:
        return 'Bookings';
      case 3:
        return 'Books';
      case 4:
        return 'User Management';
      default:
        return 'LibraryPlus';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              backgroundColor: AppTheme.primaryDark,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _getTitleForIndex(_currentIndex),
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                  tooltip: 'Notifications',
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: Colors.white70),
                  onPressed: _signOut,
                  tooltip: 'Log out',
                ),
              ],
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, 'assets/images/nav/home.svg', 'Home'),
                _buildNavItem(1, 'assets/images/nav/seats.svg', 'Seats'),
                _buildNavItem(2, 'assets/images/nav/bookings.svg', 'Bookings'),
                _buildNavItem(3, 'assets/images/nav/books.svg', 'Books'),
                _buildNavItem(4, 'assets/images/nav/profile.svg', 'Users'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String assetPath, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              assetPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                isSelected ? AppTheme.primaryDark : AppTheme.textMuted,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primaryDark : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
