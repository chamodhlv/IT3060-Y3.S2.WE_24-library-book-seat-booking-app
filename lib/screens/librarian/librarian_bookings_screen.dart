import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../models/book_reservation_model.dart';
import '../../services/seat_service.dart';
import '../../services/book_service.dart';

/// Librarian: Booking management screen with QR check-in & manual check-in.
class LibrarianBookingsScreen extends StatefulWidget {
  const LibrarianBookingsScreen({super.key});

  @override
  State<LibrarianBookingsScreen> createState() =>
      _LibrarianBookingsScreenState();
}

class _LibrarianBookingsScreenState extends State<LibrarianBookingsScreen>
    with TickerProviderStateMixin {
  late TabController _seatTabController;
  late TabController _bookTabController;
  int _selectedCategoryIndex = 0; // 0 = Seat Bookings, 1 = Book Holds
  List<SeatBooking> _bookings = [];
  List<BookReservation> _bookReservations = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _seatTabController = TabController(length: 3, vsync: this);
    _seatTabController.addListener(() => setState(() {}));
    _bookTabController = TabController(length: 3, vsync: this);
    _bookTabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _seatTabController.dispose();
    _bookTabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await SeatService().expireOldBookings();
      final seatFuture = SeatService().getAllBookings(date: _selectedDate);
      final bookFuture = BookService().getAllReservations();

      final results = await Future.wait([seatFuture, bookFuture]);
      setState(() {
        _bookings = results[0] as List<SeatBooking>;
        _bookReservations = results[1] as List<BookReservation>;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<SeatBooking> get _all => _bookings;
  List<SeatBooking> get _upcoming => _bookings
      .where((b) => b.status == BookingStatus.confirmed)
      .toList();
  List<SeatBooking> get _checkedIn => _bookings
      .where((b) => b.status == BookingStatus.checkedIn)
      .toList();

  List<BookReservation> get _holdRequests =>
      _bookReservations.where((r) => r.isReserved).toList();
  List<BookReservation> get _issuedBooks =>
      _bookReservations.where((r) => r.isBorrowed).toList();
  List<BookReservation> get _returnedBooks =>
      _bookReservations.where((r) => r.isReturned).toList();

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
              _buildDatePicker(),
              _buildSeatTabs(),
              Expanded(child: _buildSeatTabView()),
            ] else ...[
              Expanded(child: _buildBookHoldsManagementSection()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCategoryIndex == 0 ? 'Seat Bookings' : 'Book Holds',
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                Text(
                  _selectedCategoryIndex == 0
                      ? 'Manage seat check-ins & reservations'
                      : 'Manage student book hold requests & issues',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // QR Scan button
          GestureDetector(
            onTap: _openQrScanner,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 22),
            ),
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

  Widget _buildDatePicker() {
    final days = List.generate(7, (i) {
      return DateTime.now().subtract(Duration(days: 3 - i));
    });

    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        itemCount: days.length,
        itemBuilder: (ctx, i) {
          final d = days[i];
          final isSelected = _isSameDay(d, _selectedDate);
          final isToday = _isSameDay(d, DateTime.now());
          final dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = d);
              _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryDark
                      : AppTheme.divider,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isToday ? 'Today' : dayNames[d.weekday - 1],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSeatTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: 'All (${_all.length})'),
            Tab(text: 'Upcoming (${_upcoming.length})'),
            Tab(text: 'Checked In (${_checkedIn.length})'),
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
        _buildBookingList(_all),
        _buildBookingList(_upcoming),
        _buildBookingList(_checkedIn),
      ],
    );
  }

  Widget _buildBookHoldsManagementSection() {
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
                Tab(text: 'Hold Requests (${_holdRequests.length})'),
                Tab(text: 'Issued / Out (${_issuedBooks.length})'),
                Tab(text: 'Returned (${_returnedBooks.length})'),
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
                    _buildLibrarianHoldRequestsTab(_holdRequests),
                    _buildLibrarianIssuedBooksTab(_issuedBooks),
                    _buildLibrarianReturnedBooksTab(_returnedBooks),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLibrarianHoldRequestsTab(List<BookReservation> holds) {
    if (holds.isEmpty) {
      return _buildLibrarianBookPlaceholder(
        title: 'No pending book holds',
        subtitle:
            'Student book hold requests for pickup will appear here for staff approval.',
        icon: Icons.inbox_outlined,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: holds.length,
        itemBuilder: (ctx, i) => _buildLibrarianHoldCard(holds[i]),
      ),
    );
  }

  Widget _buildLibrarianHoldCard(BookReservation hold) {
    final book = hold.book;
    final expires = hold.holdExpiresAt;
    final expiryFormatted = '${expires.day}/${expires.month}/${expires.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.bookmark_added_rounded,
                        size: 20, color: AppTheme.primaryGreen),
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
                              hold.userFullName ?? 'Student',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Hold Requested',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book?.title ?? 'Book Title',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${book?.authors ?? ""} · ${book?.shelfLocation ?? "Desk"}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (hold.userStudentId != null) ...[
                            Text(
                              'ID: ${hold.userStudentId}',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'Hold until: $expiryFormatted',
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
                    onPressed: () => _issueBookDialog(hold),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      'Issue Book (Borrow)',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
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
                  onPressed: () => _cancelBookHoldDialog(hold),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrarianIssuedBooksTab(List<BookReservation> issued) {
    if (issued.isEmpty) {
      return _buildLibrarianBookPlaceholder(
        title: 'No issued books',
        subtitle:
            'Physical books currently checked out to students will be tracked here.',
        icon: Icons.assignment_outlined,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: issued.length,
        itemBuilder: (ctx, i) => _buildLibrarianIssuedCard(issued[i]),
      ),
    );
  }

  Widget _buildLibrarianIssuedCard(BookReservation reservation) {
    final book = reservation.book;
    final isOverdue = reservation.isOverdue;
    final due = reservation.dueDate;
    final dueFormatted =
        due != null ? '${due.day}/${due.month}/${due.year}' : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.menu_book_rounded,
                        size: 20, color: AppTheme.primaryDark),
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
                              reservation.userFullName ?? 'Student',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isOverdue ? 'Overdue' : 'Borrowed',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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
                        book?.title ?? 'Book Title',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Due: $dueFormatted · Shelf: ${book?.shelfLocation ?? "Desk"}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isOverdue
                              ? AppTheme.errorRed
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (reservation.userStudentId != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Student ID: ${reservation.userStudentId}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmReturnDialog(reservation),
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                label: Text(
                  'Mark as Returned',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibrarianReturnedBooksTab(List<BookReservation> returned) {
    if (returned.isEmpty) {
      return _buildLibrarianBookPlaceholder(
        title: 'No returned books',
        subtitle:
            'History of returned physical books and desk check-ins will be logged here.',
        icon: Icons.assignment_turned_in_outlined,
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: returned.length,
        itemBuilder: (ctx, i) {
          final item = returned[i];
          final book = item.book;
          final retDate = item.returnedAt ?? item.updatedAt ?? item.createdAt;
          final retDateStr = '${retDate.day}/${retDate.month}/${retDate.year}';

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
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      size: 20, color: AppTheme.primaryGreen),
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
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Returned',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Student: ${item.userFullName ?? "Unknown"} · Returned on $retDateStr',
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

  Widget _buildLibrarianBookPlaceholder({
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

  Future<void> _issueBookDialog(BookReservation hold) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Issue Book to Student',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${hold.userFullName ?? "Unknown"}',
                style: GoogleFonts.inter(fontSize: 14)),
            if (hold.userStudentId != null)
              Text('ID: ${hold.userStudentId}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Book: ${hold.book?.title ?? "Book"}',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Loan Period: 14 days (Standard policy)',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textMuted)),
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
            child: const Text('Confirm Issue'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BookService().markAsBorrowed(hold.id);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Book successfully checked out to ${hold.userFullName ?? "student"}.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _confirmReturnDialog(BookReservation reservation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Book Return',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${reservation.userFullName ?? "Unknown"}',
                style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 6),
            Text('Book: ${reservation.book?.title ?? "Book"}',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'Confirming this return will update book status to "Returned" and automatically release a copy back to shelf inventory.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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
            child: const Text('Mark as Returned'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BookService().markAsReturned(reservation.id);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Book returned and inventory updated!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _cancelBookHoldDialog(BookReservation hold) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Book Hold',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancel hold for "${hold.book?.title ?? "book"}" reserved by ${hold.userFullName ?? "student"}?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Uncollected hold expired...',
              ),
              maxLines: 2,
            ),
          ],
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
      await BookService().cancelReservation(
        hold.id,
        reason: reasonCtrl.text.trim().isEmpty
            ? 'Cancelled by librarian'
            : reasonCtrl.text.trim(),
        cancelledBy: 'librarian',
      );
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Book hold cancelled and copy returned to shelf.'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Widget _buildBookingList(List<SeatBooking> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 48,
                color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No bookings',
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildBookingCard(items[i]),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(SeatBooking booking) {
    final seat = booking.seat;
    final isConfirmed = booking.status == BookingStatus.confirmed;
    final isCheckedIn = booking.status == BookingStatus.checkedIn;

    Color statusColor = AppTheme.primaryGreen;
    String statusText = 'Confirmed';
    if (isCheckedIn) {
      statusColor = AppTheme.successGreen;
      statusText = 'Checked In';
    } else if (booking.status == BookingStatus.cancelled) {
      statusColor = AppTheme.errorRed;
      statusText = 'Cancelled';
    } else if (booking.status == BookingStatus.noShow ||
        booking.status == BookingStatus.expired) {
      statusColor = AppTheme.textMuted;
      statusText = 'No Show';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      seat?.label ?? '?',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryGreen),
                    ),
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
                              booking.userFullName ?? 'Unknown Student',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusText,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${seat?.section.displayName ?? ''} · ${booking.timeRangeDisplay}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      if (booking.userStudentId != null)
                        Text(
                          'ID: ${booking.userStudentId}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isConfirmed) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _checkIn(booking),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text('Manual Check-in',
                          style: GoogleFonts.inter(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _cancelBookingDialog(booking),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkIn(SeatBooking booking) async {
    try {
      await SeatService().checkIn(booking.id);
      // Notify the student
      await SeatService().createNotification(
        userId: booking.userId,
        title: 'Checked In ✓',
        body:
            'You have been checked in for ${booking.seat?.label ?? 'your seat'} at ${booking.timeRangeDisplay}.',
        type: 'booking_checkin',
        relatedBookingId: booking.id,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  Future<void> _cancelBookingDialog(SeatBooking booking) async {
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Booking',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Cancel ${booking.userFullName ?? "student"}\'s booking for ${booking.seat?.label ?? "seat"} at ${booking.timeRangeDisplay}?',
                style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                hintText: 'e.g. Policy violation, maintenance...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Booking',
                style: GoogleFonts.inter(
                    color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SeatService().cancelBooking(
        booking.id,
        reason: reasonCtrl.text.trim().isEmpty ? 'Cancelled by librarian' : reasonCtrl.text.trim(),
        cancelledBy: 'librarian',
      );

      // Notify the student
      await SeatService().createNotification(
        userId: booking.userId,
        title: 'Booking Cancelled by Library Staff',
        body:
            'Your booking for ${booking.seat?.label ?? 'seat'} at ${booking.timeRangeDisplay} was cancelled. Reason: ${reasonCtrl.text.trim().isEmpty ? 'No reason provided' : reasonCtrl.text.trim()}',
        type: 'booking_cancelled',
        relatedBookingId: booking.id,
      );

      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QrScannerScreen(
          onScanned: (token) async {
            Navigator.pop(context);
            await _handleQrScan(token);
          },
        ),
      ),
    );
  }

  Future<void> _handleQrScan(String token) async {
    try {
      // 1. Check if token belongs to a Book Reservation
      final bookRes = await BookService().getReservationByQrToken(token);
      if (bookRes != null) {
        if (!mounted) return;
        await _handleBookQrAction(bookRes);
        return;
      }

      // 2. Check if token belongs to a Seat Booking
      final booking = await SeatService().getBookingByQrToken(token);
      if (booking != null) {
        if (booking.status != BookingStatus.confirmed) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Seat booking status: ${booking.status.displayName}. Cannot check in.'),
                backgroundColor: AppTheme.warningAmber),
          );
          return;
        }

        // Show confirm dialog
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.background,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Confirm Check-in',
                    style: GoogleFonts.inter(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _checkIn(booking);
        }
        return;
      }

      // If neither found
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No reservation or seat booking found for this QR code.'),
            backgroundColor: AppTheme.errorRed),
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
        _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Book "${res.book?.title ?? "book"}" successfully issued to ${res.userFullName}!'),
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
        _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book return processed! Stock restored.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } else if (res.status == BookReservationStatus.returned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This book was already marked as returned.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This book reservation is cancelled.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// QR Scanner screen using mobile_scanner.
class _QrScannerScreen extends StatefulWidget {
  final void Function(String token) onScanned;

  const _QrScannerScreen({required this.onScanned});

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                widget.onScanned(barcode!.rawValue!);
              }
            },
          ),
          // Overlay
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Scan Check-in QR Code',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Point the camera at the student\'s QR code',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
