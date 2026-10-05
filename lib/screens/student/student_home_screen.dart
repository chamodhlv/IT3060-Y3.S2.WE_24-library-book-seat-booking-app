import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/book_model.dart';
import '../../models/seat_model.dart';
import '../../models/book_reservation_model.dart';
import '../../services/auth_service.dart';
import '../../services/seat_service.dart';
import '../../services/book_service.dart';
import '../shared/notifications_screen.dart';
import 'booking_confirmation_screen.dart';
import 'book_reservation_confirmation_screen.dart';

/// Student: Rich, modern home screen with dynamic greeting, active reservations,
/// quick shortcuts, catalogue highlights, and live library status.
class StudentHomeScreen extends StatefulWidget {
  final void Function(int tabIndex) onNavigateTab;

  const StudentHomeScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  AppUser? _user;
  bool _isLoading = true;
  int _unreadNotifsCount = 0;

  // Active bookings
  List<SeatBooking> _upcomingSeats = [];
  List<BookReservation> _activeHolds = [];
  List<Book> _featuredBooks = [];

  // Capacity stats
  int _totalActiveSeats = 0;
  int _availableCopiesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = AuthService().currentUser;
    setState(() {
      _user = user;
      _isLoading = true;
    });

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Expire old seat bookings safely
      try {
        await SeatService().expireOldBookings();
      } catch (_) {}

      // 2. Fetch parallel data
      final notifCountFuture = SeatService().getUnreadCount(user.id);
      final seatBookingsFuture = SeatService().getStudentBookings(user.id);
      final bookHoldsFuture = BookService().getStudentReservations(user.id);
      final booksFuture = BookService().getBooks();
      final seatsFuture = SeatService().getSeats();

      final results = await Future.wait([
        notifCountFuture,
        seatBookingsFuture,
        bookHoldsFuture,
        booksFuture,
        seatsFuture,
      ]);

      if (!mounted) return;

      final unreadCount = results[0] as int;
      final seatBookings = results[1] as List<SeatBooking>;
      final bookHolds = results[2] as List<BookReservation>;
      final books = results[3] as List<Book>;
      final seats = results[4] as List<Seat>;

      final upcoming = seatBookings
          .where((b) =>
              (b.status == BookingStatus.confirmed ||
                  b.status == BookingStatus.checkedIn) &&
              !b.isPast)
          .toList();

      final currentHolds =
          bookHolds.where((r) => r.isReserved).toList();

      int availableCopies = 0;
      for (final b in books) {
        availableCopies += b.availableCopies;
      }

      setState(() {
        _unreadNotifsCount = unreadCount;
        _upcomingSeats = upcoming;
        _activeHolds = currentHolds;
        _featuredBooks = books;
        _totalActiveSeats = seats.length;
        _availableCopiesCount = availableCopies;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final firstName = user?.fullName.split(' ').first ?? 'Student';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading && _featuredBooks.isEmpty && _upcomingSeats.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryDark),
              )
            : RefreshIndicator(
                color: AppTheme.primaryDark,
                onRefresh: _loadData,
                child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(firstName),
                const SizedBox(height: 18),
                _buildLibraryPulseBanner(),
                const SizedBox(height: 20),
                _buildActiveReservationsSpotlight(),
                const SizedBox(height: 24),
                _buildQuickActionsGrid(),
                const SizedBox(height: 24),
                _buildFeaturedBooksSection(),
                const SizedBox(height: 24),
                _buildFacilitiesCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────────

  Widget _buildHeader(String firstName) {
    return Row(
      children: [
        // Avatar with Initials
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _user?.initials ?? 'ST',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Greeting & ID
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '$_greeting, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('👋', style: TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _user?.studentStaffId.isNotEmpty == true
                    ? 'ID: ${_user!.studentStaffId}'
                    : 'Library Student Member',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Notification Bell Icon with Badge
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            _loadData();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: AppTheme.textPrimary,
                ),
                if (_unreadNotifsCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── LIBRARY STATUS & LIVE STATS ────────────────────────────────────────

  Widget _buildLibraryPulseBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Library Open · 8:00 AM – 8:00 PM',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Quiet Hours',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPulseStat(
                icon: Icons.event_seat_rounded,
                iconColor: AppTheme.primaryGreen,
                value: '$_totalActiveSeats Available',
                label: 'Desks & Pods',
                onTap: () => widget.onNavigateTab(1),
              ),
              Container(width: 1, height: 28, color: AppTheme.divider),
              _buildPulseStat(
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF2E86C1),
                value: '$_availableCopiesCount On Shelf',
                label: 'Physical Copies',
                onTap: () => widget.onNavigateTab(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulseStat({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIVE RESERVATIONS SPOTLIGHT ──────────────────────────────────────

  Widget _buildActiveReservationsSpotlight() {
    final hasUpcomingSeat = _upcomingSeats.isNotEmpty;
    final hasActiveHold = _activeHolds.isNotEmpty;

    if (!hasUpcomingSeat && !hasActiveHold) {
      return _buildWelcomeBanner();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ACTIVE RESERVATIONS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onNavigateTab(2),
              child: Text(
                'View all',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hasUpcomingSeat) _buildUpcomingSeatCard(_upcomingSeats.first),
        if (hasUpcomingSeat && hasActiveHold) const SizedBox(height: 10),
        if (hasActiveHold) _buildActiveHoldCard(_activeHolds.first),
      ],
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2D3D), Color(0xFF2C3E50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2D3D).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      'Ready to Study',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.local_library_rounded,
                  color: Colors.white54, size: 28),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Reserve Desks & Books in Seconds',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick your favorite seat with power outlet or reserve a physical textbook for desk pickup.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => widget.onNavigateTab(1),
                icon: const Icon(Icons.event_seat_rounded, size: 16),
                label: const Text('Book a Seat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab(3),
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('Catalogue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSeatCard(SeatBooking b) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_seat_rounded,
                size: 22, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      b.seat?.label ?? 'Seat Reserved',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        b.isToday ? 'Today' : 'Upcoming',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${b.seat?.section.displayName ?? "Main Hall"} · ${b.timeRangeDisplay}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (b.seat != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingConfirmationScreen(
                      booking: b,
                      seat: b.seat!,
                    ),
                  ),
                );
              } else {
                widget.onNavigateTab(2);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Show QR',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveHoldCard(BookReservation hold) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bookmark_added_rounded,
                size: 22, color: Color(0xFF92400E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hold.book?.title ?? 'Held Book',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Held for pickup',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Shelf: ${hold.book?.shelfLocation ?? "Desk"} · ${hold.book?.authors ?? ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (hold.book != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookReservationConfirmationScreen(
                      reservation: hold,
                      book: hold.book!,
                    ),
                  ),
                );
              } else {
                widget.onNavigateTab(2);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF92400E),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Pickup QR',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS GRID ─────────────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPLORE SERVICES',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'Book Seat',
                subtitle: 'Desks & pods',
                icon: Icons.event_seat_rounded,
                color: AppTheme.primaryGreen,
                onTap: () => widget.onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Book Catalogue',
                subtitle: 'Browse & reserve',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF2E86C1),
                onTap: () => widget.onNavigateTab(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'My Bookings',
                subtitle: 'Passes & QR codes',
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFFD97706),
                onTap: () => widget.onNavigateTab(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Student Profile',
                subtitle: 'Account & history',
                icon: Icons.account_circle_outlined,
                color: AppTheme.primaryDark,
                onTap: () => widget.onNavigateTab(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FEATURED BOOKS CAROUSEL ────────────────────────────────────────────

  Widget _buildFeaturedBooksSection() {
    if (_featuredBooks.isEmpty) return const SizedBox.shrink();

    final displayBooks = _featuredBooks.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'FEATURED CATALOGUE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => widget.onNavigateTab(3),
              child: Text(
                'Browse all',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayBooks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final b = displayBooks[i];
              return _buildFeaturedBookCard(b, i);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedBookCard(Book book, int index) {
    const avatarColors = [
      Color(0xFF1E2D3D),
      Color(0xFF5B8A72),
      Color(0xFF3B5998),
      Color(0xFF6B4226),
      Color(0xFF8E44AD),
      Color(0xFF2E86C1),
    ];
    final color = avatarColors[index % avatarColors.length];

    return GestureDetector(
      onTap: () => widget.onNavigateTab(3),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover initials badge
            Container(
              width: double.infinity,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                book.initials,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.25,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: book.hasAvailableCopy
                        ? AppTheme.primaryGreen
                        : AppTheme.errorRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    book.hasAvailableCopy
                        ? '${book.availableCopies} available'
                        : 'Borrowed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: book.hasAvailableCopy
                          ? AppTheme.primaryGreen
                          : AppTheme.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── FACILITIES & AMENITIES CARD ────────────────────────────────────────

  Widget _buildFacilitiesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, size: 20, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Library Amenities & Rules',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAmenityRow(Icons.wifi_rounded, 'Campus High-Speed Wi-Fi 6 (LibraryPlus-Net)'),
          const SizedBox(height: 10),
          _buildAmenityRow(Icons.power_rounded, 'Universal power outlets on desk rows A & C'),
          const SizedBox(height: 10),
          _buildAmenityRow(Icons.groups_rounded, '4 Pods with dry-erase whiteboards for group study'),
          const SizedBox(height: 10),
          _buildAmenityRow(Icons.volume_off_rounded, 'Strict quiet policy on 2nd Floor Silent Hall'),
        ],
      ),
    );
  }

  Widget _buildAmenityRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
