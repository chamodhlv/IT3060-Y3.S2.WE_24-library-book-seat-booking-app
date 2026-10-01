import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../services/seat_service.dart';
import '../../services/auth_service.dart';

/// Student: My bookings screen.
class StudentBookingsScreen extends StatefulWidget {
  const StudentBookingsScreen({super.key});

  @override
  State<StudentBookingsScreen> createState() => _StudentBookingsScreenState();
}

class _StudentBookingsScreenState extends State<StudentBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SeatBooking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = AuthService().currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Expire overdue bookings safely
      try {
        await SeatService().expireOldBookings();
      } catch (_) {}

      final bookings = await SeatService().getStudentBookings(user.id);
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<SeatBooking> get _upcoming => _bookings
      .where((b) =>
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.checkedIn) &&
          !b.isPast)
      .toList();

  List<SeatBooking> get _past => _bookings
      .where((b) =>
          b.status == BookingStatus.cancelled ||
          b.status == BookingStatus.expired ||
          b.status == BookingStatus.noShow ||
          b.isPast)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(child: _buildTabView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final active = _upcoming.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Bookings',
                    style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                if (active > 0)
                  Text('$active active reservation${active > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppTheme.primaryGreen)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppTheme.textPrimary,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppTheme.primaryDark,
            borderRadius: BorderRadius.circular(20),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryDark));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildList(_upcoming, isUpcoming: true),
        _buildList(_past, isUpcoming: false),
      ],
    );
  }

  Widget _buildList(List<SeatBooking> items, {required bool isUpcoming}) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primaryDark,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 48,
                    color: AppTheme.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  isUpcoming ? 'No upcoming bookings' : 'No past bookings',
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group by relative date
    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final booking = items[i];
          // Section header
          String? header;
          if (i == 0 || _dayLabel(items[i - 1].date) != _dayLabel(booking.date)) {
            header = _dayLabel(booking.date);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) ...[
                if (i > 0) const SizedBox(height: 8),
                Text(header,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
              ],
              _buildBookingCard(booking, isUpcoming: isUpcoming),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(SeatBooking booking, {required bool isUpcoming}) {
    final seat = booking.seat;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_seat_outlined,
                      size: 20, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seat != null
                            ? '${seat.label} · ${seat.section.displayName}'
                            : 'Seat Booking',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.timeRangeDisplay} · ${_statusLabel(booking.status)}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.status == BookingStatus.checkedIn
                            ? 'Checked in ✓'
                            : 'Check-in is confirmed by library staff on arrival.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUpcoming) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showQrDialog(booking),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      child: Text('View at desk',
                          style: GoogleFonts.inter(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelBooking(booking),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showQrDialog(SeatBooking booking) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Check-in QR Code',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (booking.qrToken != null)
                QrImageView(
                  data: booking.qrToken!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              const SizedBox(height: 12),
              Text('Show this to the desk scanner',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              // Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Awaiting check-in · Held',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF92400E))),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelBooking(SeatBooking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel booking?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to cancel your booking for ${booking.seat?.label ?? 'this seat'} at ${booking.timeRangeDisplay}?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel booking',
                style: GoogleFonts.inter(
                    color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SeatService().cancelBooking(booking.id, cancelledBy: 'student');

      // Notify librarians (could also notify user themselves)
      await SeatService().createNotification(
        userId: booking.userId,
        title: 'Booking Cancelled',
        body:
            'Your booking for ${booking.seat?.label ?? 'seat'} at ${booking.timeRangeDisplay} has been cancelled.',
        type: 'booking_cancelled',
        relatedBookingId: booking.id,
      );

      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed),
      );
    }
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.checkedIn:
        return 'Checked In';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.expired:
      case BookingStatus.noShow:
        return 'No Show';
    }
  }
}
