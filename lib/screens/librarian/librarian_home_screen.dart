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
import '../shared/qr_scanner_screen.dart';

/// Librarian: Operations Dashboard & Command Center.
class LibrarianHomeScreen extends StatefulWidget {
  final void Function(int tabIndex) onNavigateTab;
  final VoidCallback onSignOut;

  const LibrarianHomeScreen({
    super.key,
    required this.onNavigateTab,
    required this.onSignOut,
  });

  @override
  State<LibrarianHomeScreen> createState() => _LibrarianHomeScreenState();
}

class _LibrarianHomeScreenState extends State<LibrarianHomeScreen> {
  AppUser? _user;
  bool _isLoading = true;

  // Real-time data
  List<BookReservation> _allReservations = [];
  List<SeatBooking> _todaySeatBookings = [];
  List<Book> _allBooks = [];
  List<Seat> _allSeats = [];

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

    try {
      // 1. Expire old seat bookings safely
      try {
        await SeatService().expireOldBookings();
      } catch (_) {}

      // 2. Fetch parallel operations data
      final reservationsFuture = BookService().getAllReservations();
      final seatsTodayFuture =
          SeatService().getAllBookings(date: DateTime.now());
      final booksFuture = BookService().getAllBooks();
      final seatsFuture = SeatService().getAllSeats();

      final results = await Future.wait([
        reservationsFuture,
        seatsTodayFuture,
        booksFuture,
        seatsFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _allReservations = results[0] as List<BookReservation>;
        _todaySeatBookings = results[1] as List<SeatBooking>;
        _allBooks = results[2] as List<Book>;
        _allSeats = results[3] as List<Seat>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<BookReservation> get _pendingHolds =>
      _allReservations.where((r) => r.isReserved).toList();

  List<BookReservation> get _issuedBooks =>
      _allReservations.where((r) => r.isBorrowed).toList();

  List<SeatBooking> get _confirmedSeatsToday => _todaySeatBookings
      .where((b) => b.status == BookingStatus.confirmed)
      .toList();

  List<SeatBooking> get _checkedInSeatsToday => _todaySeatBookings
      .where((b) => b.status == BookingStatus.checkedIn)
      .toList();

  // ─── QR SCANNER HANDLER ──────────────────────────────────────────────────

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          title: 'Desk Scanner',
          instruction: 'Point camera at student QR pass to check in or loan books',
          onScanned: (token) async {
            Navigator.pop(context);
            await _handleScannedToken(token);
          },
        ),
      ),
    );
  }

  Future<void> _handleScannedToken(String token) async {
    try {
      // 1. Check if token belongs to a Book Reservation
      final bookRes = await BookService().getReservationByQrToken(token);
      if (bookRes != null) {
        if (!mounted) return;
        await _handleBookQrAction(bookRes);
        return;
      }

      // 2. Check if token belongs to a Seat Booking
      final seatBooking = await SeatService().getBookingByQrToken(token);
      if (seatBooking != null) {
        if (!mounted) return;
        await _handleSeatQrAction(seatBooking);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reservation found for this QR code.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _handleBookQrAction(BookReservation res) async {
    if (res.status == BookReservationStatus.reserved) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Issue Reserved Book',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${res.userFullName ?? "Unknown"}',
                  style: GoogleFonts.inter(fontSize: 14)),
              if (res.userStudentId != null)
                Text('Student ID: ${res.userStudentId}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text('Book: ${res.book?.title ?? "Book"}',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (res.book?.shelfLocation != null)
                Text('Shelf: ${res.book!.shelfLocation}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded,
                        size: 20, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR code verified. Click confirm to mark this book as borrowed.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Issue (Borrow)'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await BookService().markAsBorrowed(res.id);
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Book "${res.book?.title ?? "book"}" successfully issued!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } else if (res.status == BookReservationStatus.borrowed) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Process Book Return',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${res.userFullName ?? "Unknown"}',
                  style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(height: 6),
              Text('Book: ${res.book?.title ?? "Book"}',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(
                'Confirm return to increment available stock and complete this loan.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Return'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await BookService().markAsReturned(res.id);
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book return processed! Stock restored.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _handleSeatQrAction(SeatBooking booking) async {
    if (booking.status != BookingStatus.confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Seat booking status: ${booking.status.displayName}. Cannot check in.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Seat Check In',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${booking.userFullName ?? 'Unknown'}',
                style: GoogleFonts.inter(fontSize: 14)),
            Text('Seat: ${booking.seat?.label ?? 'N/A'}',
                style: GoogleFonts.inter(fontSize: 14)),
            Text('Time: ${booking.timeRangeDisplay}',
                style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Check-in'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SeatService().checkIn(booking.id);
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student checked in to seat!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final staffName = _user?.fullName.isNotEmpty == true
        ? _user!.fullName
        : 'Library Staff';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading && _allReservations.isEmpty && _todaySeatBookings.isEmpty
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
                _buildStaffHeader(staffName),
                _buildOperationsPulse(),
                const SizedBox(height: 22),
                _buildDeskMetricsGrid(),
                const SizedBox(height: 22),
                _buildQuickOperationsCard(),
                const SizedBox(height: 24),
                _buildPendingActionQueue(),
                const SizedBox(height: 24),
                _buildSystemOverviewCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── STAFF HEADER ────────────────────────────────────────────────────────

  Widget _buildStaffHeader(String staffName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.all(Radius.circular(26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.avatarOrange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _user?.initials ?? 'LP',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIBRARIAN DESK',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  staffName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Today\'s service overview',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _buildHeaderIcon(
                icon: Icons.qr_code_scanner_rounded,
                tooltip: 'Scan QR',
                onTap: _openQrScanner,
              ),
              const SizedBox(height: 6),
              _buildHeaderIcon(
                icon: Icons.logout_rounded,
                tooltip: 'Sign out',
                onTap: widget.onSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildOperationsPulse() {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
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
              Expanded(
                child: Text(
                  'Library desk open',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '8:00 AM – 8:00 PM',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildPulseTile(
                  icon: Icons.event_seat_rounded,
                  color: AppTheme.primaryGreen,
                  value: '${_todaySeatBookings.length}',
                  label: 'Seats scheduled',
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPulseTile(
                  icon: Icons.bookmark_added_rounded,
                  color: const Color(0xFFD97706),
                  value: '${_pendingHolds.length}',
                  label: 'Holds to process',
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPulseTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
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

  // ─── DESK METRICS GRID ───────────────────────────────────────────────────

  Widget _buildDeskMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESK METRICS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Pending Holds',
                value: '${_pendingHolds.length}',
                subtitle: 'Awaiting student pickup',
                badgeText: _pendingHolds.isNotEmpty ? 'Action needed' : 'Clear',
                badgeColor: _pendingHolds.isNotEmpty
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFDCFCE7),
                badgeTextColor: _pendingHolds.isNotEmpty
                    ? const Color(0xFF92400E)
                    : const Color(0xFF16A34A),
                icon: Icons.bookmark_added_rounded,
                iconColor: const Color(0xFFD97706),
                onTap: () => widget.onNavigateTab(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Active Loans',
                value: '${_issuedBooks.length}',
                subtitle: 'Books checked out',
                badgeText: 'In circulation',
                badgeColor: const Color(0xFFEFF6FF),
                badgeTextColor: const Color(0xFF1D4ED8),
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF2563EB),
                onTap: () => widget.onNavigateTab(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Today's Seats",
                value: '${_todaySeatBookings.length}',
                subtitle: _allSeats.isNotEmpty
                    ? '${_checkedInSeatsToday.length} active / ${_allSeats.length} capacity'
                    : '${_checkedInSeatsToday.length} checked in',
                badgeText: '${_confirmedSeatsToday.length} waiting',
                badgeColor: const Color(0xFFDCFCE7),
                badgeTextColor: const Color(0xFF16A34A),
                icon: Icons.event_seat_rounded,
                iconColor: AppTheme.primaryGreen,
                onTap: () => widget.onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Catalogue Stock',
                value: '${_allBooks.length}',
                subtitle: 'Library titles',
                badgeText: 'Inventory',
                badgeColor: AppTheme.surfaceLight,
                badgeTextColor: AppTheme.textPrimary,
                icon: Icons.inventory_2_outlined,
                iconColor: AppTheme.primaryDark,
                onTap: () => widget.onNavigateTab(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK OPERATIONS BAR ────────────────────────────────────────────────

  Widget _buildQuickOperationsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded,
                  color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 8),
              Text(
                'Desk Operations Shortcuts',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildOpButton(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan QR',
                onTap: _openQrScanner,
              ),
              _buildOpButton(
                icon: Icons.bookmark_added_rounded,
                label: 'Book Holds',
                onTap: () => widget.onNavigateTab(2),
              ),
              _buildOpButton(
                icon: Icons.assignment_turned_in_rounded,
                label: 'Returns',
                onTap: () => widget.onNavigateTab(2),
              ),
              _buildOpButton(
                icon: Icons.manage_accounts_rounded,
                label: 'Students',
                onTap: () => widget.onNavigateTab(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PENDING ACTION QUEUE ────────────────────────────────────────────────

  Widget _buildPendingActionQueue() {
    final pendingHolds = _pendingHolds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PENDING HOLDS QUEUE',
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
                'Manage all',
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
        if (pendingHolds.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 24, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All book holds processed!',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'No pending student hold requests waiting for pickup.',
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
          )
        else
          Column(
            children: pendingHolds.take(3).map((hold) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bookmark_added_rounded,
                          size: 18, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hold.book?.title ?? 'Book Title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Student: ${hold.userFullName ?? "Unknown"} · Shelf: ${hold.book?.shelfLocation ?? "Desk"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _issueDirect(hold),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Issue',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _issueDirect(BookReservation hold) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Issue Book to Student',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Issue "${hold.book?.title ?? "book"}" to ${hold.userFullName ?? "student"} with standard 14 days loan period?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Issue'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BookService().markAsBorrowed(hold.id);
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Book issued to ${hold.userFullName ?? "student"}.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  // ─── SYSTEM OVERVIEW CARD ────────────────────────────────────────────────

  Widget _buildSystemOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_outlined,
                  size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Library System Status',
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
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Online · Healthy',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Supabase Database Connected · Desk QR Scanner Active · Real-time Seat Occupancy & Stock Tracking Enabled.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
