import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../models/book_reservation_model.dart';
import '../../services/seat_service.dart';
import '../../services/book_service.dart';
import '../../services/auth_service.dart';

/// Student: My bookings screen.
class StudentBookingsScreen extends StatefulWidget {
  const StudentBookingsScreen({super.key});

  @override
  State<StudentBookingsScreen> createState() => _StudentBookingsScreenState();
}

class _StudentBookingsScreenState extends State<StudentBookingsScreen>
    with TickerProviderStateMixin {
  late TabController _seatTabController;
  late TabController _bookTabController;
  int _selectedCategoryIndex = 0; // 0 = Seats, 1 = Books
  List<SeatBooking> _bookings = [];
  List<BookReservation> _bookReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _seatTabController = TabController(length: 2, vsync: this);
    _bookTabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _seatTabController.dispose();
    _bookTabController.dispose();
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
      // Expire overdue seat bookings safely
      try {
        await SeatService().expireOldBookings();
      } catch (_) {}

      final seatBookingsFuture = SeatService().getStudentBookings(user.id);
      final bookReservationsFuture =
          BookService().getStudentReservations(user.id);

      final results = await Future.wait([
        seatBookingsFuture,
        bookReservationsFuture,
      ]);

      if (mounted) {
        setState(() {
          _bookings = results[0] as List<SeatBooking>;
          _bookReservations = results[1] as List<BookReservation>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<BookReservation> get _currentHolds =>
      _bookReservations.where((r) => r.isPickupAvailable).toList();

  List<BookReservation> get _borrowedBooks =>
      _bookReservations.where((r) => r.isBorrowed).toList();

  List<BookReservation> get _bookHistory => _bookReservations
      .where((r) => r.isReturned || r.isCancelled)
      .toList();

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
            _buildCategorySelector(),
            if (_selectedCategoryIndex == 0) ...[
              _buildSeatTabs(),
              Expanded(child: _buildSeatTabView()),
            ] else ...[
              Expanded(child: _buildBookHoldsSection()),
            ],
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
                Text(
                  _selectedCategoryIndex == 0 ? 'My Seat Bookings' : 'My Book Holds',
                  style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                Text(
                  _selectedCategoryIndex == 0
                      ? (active > 0
                          ? '$active active reservation${active > 1 ? 's' : ''}'
                          : 'No active seat reservations')
                      : (_currentHolds.isNotEmpty
                          ? '${_currentHolds.length} active hold${_currentHolds.length > 1 ? 's' : ''} awaiting pickup'
                          : (_borrowedBooks.isNotEmpty
                              ? '${_borrowedBooks.length} book${_borrowedBooks.length > 1 ? 's' : ''} currently borrowed'
                              : 'Physical book reservations & holds')),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: (_selectedCategoryIndex == 0 && active > 0) ||
                              (_selectedCategoryIndex == 1 &&
                                  (_currentHolds.isNotEmpty ||
                                      _borrowedBooks.isNotEmpty))
                          ? AppTheme.primaryGreen
                          : AppTheme.textSecondary),
                ),
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

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _selectedCategoryIndex == 0
                        ? AppTheme.primaryDark
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_seat_outlined,
                        size: 16,
                        color: _selectedCategoryIndex == 0
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Seats',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedCategoryIndex == 0
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategoryIndex = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _selectedCategoryIndex == 1
                        ? AppTheme.primaryDark
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 16,
                        color: _selectedCategoryIndex == 1
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Books',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedCategoryIndex == 1
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TabBar(
          controller: _seatTabController,
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

  Widget _buildSeatTabView() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryDark));
    }

    return TabBarView(
      controller: _seatTabController,
      children: [
        _buildList(_upcoming, isUpcoming: true),
        _buildList(_past, isUpcoming: false),
      ],
    );
  }

  Widget _buildBookHoldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _bookTabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Holds (${_currentHolds.length})'),
                Tab(text: 'Borrowed (${_borrowedBooks.length})'),
                Tab(text: 'History (${_bookHistory.length})'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryDark))
              : TabBarView(
                  controller: _bookTabController,
                  children: [
                    _buildHoldsTabList(_currentHolds),
                    _buildBorrowedTabList(_borrowedBooks),
                    _buildBookHistoryTabList(_bookHistory),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHoldsTabList(List<BookReservation> holds) {
    if (holds.isEmpty) {
      return _buildBookTabPlaceholder(
        title: 'No active book holds',
        subtitle:
            'Reserve copies from the library catalogue to hold them for desk pickup.',
        icon: Icons.bookmark_added_outlined,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: holds.length,
        itemBuilder: (ctx, i) => _buildHoldCard(holds[i]),
      ),
    );
  }

  Widget _buildHoldCard(BookReservation hold) {
    final book = hold.book;
    final expires = hold.holdExpiresAt;
    final expiryFormatted = '${expires.day}/${expires.month}/${expires.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bookmark_added_rounded,
                      size: 22, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              book?.title ?? 'Reserved Book',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
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
                        book?.authors ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (book?.shelfLocation != null) ...[
                            Icon(Icons.location_on_outlined,
                                size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              book!.shelfLocation!,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Icon(Icons.access_time_rounded,
                              size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            'Hold until $expiryFormatted',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showBookQrDialog(hold),
                    icon: const Icon(Icons.qr_code_rounded, size: 16),
                    label: Text('Show QR at Desk',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _cancelHold(hold),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Cancel Hold',
                      style: GoogleFonts.inter(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowedTabList(List<BookReservation> borrowed) {
    if (borrowed.isEmpty) {
      return _buildBookTabPlaceholder(
        title: 'No borrowed books',
        subtitle:
            'Books you currently have checked out from the library will appear here.',
        icon: Icons.menu_book_outlined,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: borrowed.length,
        itemBuilder: (ctx, i) => _buildBorrowedCard(borrowed[i]),
      ),
    );
  }

  Widget _buildBorrowedCard(BookReservation reservation) {
    final book = reservation.book;
    final isOverdue = reservation.isOverdue;
    final due = reservation.dueDate;
    final dueFormatted =
        due != null ? '${due.day}/${due.month}/${due.year}' : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      size: 22, color: AppTheme.primaryDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              book?.title ?? 'Borrowed Book',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? const Color(0xFFFFE4E4)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isOverdue ? 'Overdue' : 'Borrowed',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isOverdue
                                    ? AppTheme.errorRed
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book?.authors ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13,
                              color: isOverdue
                                  ? AppTheme.errorRed
                                  : AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Due: $dueFormatted',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isOverdue
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isOverdue
                                  ? AppTheme.errorRed
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Return this book at the library desk. Only the librarian can confirm and mark it as returned.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppTheme.textMuted, height: 1.3),
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

  Widget _buildBookHistoryTabList(List<BookReservation> history) {
    if (history.isEmpty) {
      return _buildBookTabPlaceholder(
        title: 'No borrowing history',
        subtitle:
            'Returned books and past holds will be recorded here.',
        icon: Icons.history_rounded,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: history.length,
        itemBuilder: (ctx, i) {
          final item = history[i];
          final book = item.book;
          final isReturned = item.isReturned;
          final statusColor =
              isReturned ? AppTheme.primaryGreen : AppTheme.errorRed;
          final statusBg = isReturned
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFFFE4E4);
          final statusText = isReturned ? 'Returned' : 'Cancelled';

          DateTime? eventDate = isReturned ? item.returnedAt : item.cancelledAt;
          eventDate ??= item.updatedAt ?? item.createdAt;
          final dateStr =
              '${eventDate.day}/${eventDate.month}/${eventDate.year}';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isReturned
                        ? Icons.check_circle_outline_rounded
                        : Icons.close_rounded,
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              book?.title ?? 'Book',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr · ${book?.authors ?? ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBookQrDialog(BookReservation reservation) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Book Pickup QR Code',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                reservation.book?.title ?? 'Reserved Book',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              if (reservation.qrToken != null)
                QrImageView(
                  data: reservation.qrToken!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                )
              else
                const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(Icons.qr_code_2_rounded,
                        size: 80, color: AppTheme.textMuted),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Show this to the desk scanner',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Awaiting Pickup · Held',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
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

  Future<void> _cancelHold(BookReservation hold) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Book Hold?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to cancel your hold for "${hold.book?.title ?? "this book"}"? The reserved copy will be released to other students.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Hold',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Hold',
              style: GoogleFonts.inter(
                  color: AppTheme.errorRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BookService().cancelReservation(hold.id, cancelledBy: 'student');
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Widget _buildBookTabPlaceholder({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 28, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
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
