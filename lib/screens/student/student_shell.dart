import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import 'profile_screen.dart';
import 'student_seats_screen.dart';
import 'student_bookings_screen.dart';

/// Placeholder screen for features not yet implemented.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Student bottom navigation shell.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;
  int _bookingsKeyCounter = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _PlaceholderScreen(title: 'Home', icon: Icons.home_outlined),
      const StudentSeatsScreen(),
      StudentBookingsScreen(key: ValueKey(_bookingsKeyCounter)),
      const _PlaceholderScreen(title: 'Books', icon: Icons.menu_book_outlined),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
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
                _buildNavItem(4, 'assets/images/nav/profile.svg', 'Profile'),
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
      onTap: () => setState(() {
        _currentIndex = index;
        if (index == 2) _bookingsKeyCounter++;
      }),
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
