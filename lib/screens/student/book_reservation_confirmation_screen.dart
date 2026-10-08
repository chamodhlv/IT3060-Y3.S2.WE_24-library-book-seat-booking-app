import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/book_model.dart';
import '../../models/book_reservation_model.dart';
import '../../services/book_service.dart';

/// Screen showing book reservation confirmation and pickup QR code.
class BookReservationConfirmationScreen extends StatefulWidget {
  final BookReservation reservation;
  final Book book;

  const BookReservationConfirmationScreen({
    super.key,
    required this.reservation,
    required this.book,
  });

  @override
  State<BookReservationConfirmationScreen> createState() =>
      _BookReservationConfirmationScreenState();
}

class _BookReservationConfirmationScreenState
    extends State<BookReservationConfirmationScreen> {
  // 0 = confirmation, 1 = QR code
  int _page = 0;
  late BookReservation _reservation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final latest =
          await BookService().getReservationById(_reservation.id);
      if (mounted && latest != null) {
        setState(() => _reservation = latest);
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _page == 0 ? _buildConfirmPage() : _buildQrPage(),
        ),
      ),
    );
  }

  Widget _buildConfirmPage() {
    final r = _reservation;
    final book = widget.book;
    final expires = r.holdExpiresAt;
    final expiryFormatted =
        '${_monthName(expires.month)} ${expires.day}, ${expires.year}';

    return Column(
      key: const ValueKey('confirm'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        // Green check circle
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 24),
        Text(
          'Book Reserved!',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '"${book.title}" is now held for you at the library desk.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Detail card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                _detailRow('Book', book.title),
                const Divider(height: 1, color: AppTheme.divider),
                _detailRow('Author(s)', book.authors),
                const Divider(height: 1, color: AppTheme.divider),
                if (book.shelfLocation != null && book.shelfLocation!.isNotEmpty) ...[
                  _detailRow('Location', book.shelfLocation!),
                  const Divider(height: 1, color: AppTheme.divider),
                ],
                _detailRow('Hold Expiration', 'Pickup by $expiryFormatted'),
                const Divider(height: 1, color: AppTheme.divider),
                _detailRow('Status', _statusLabel(r)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Present your QR code at the desk so the librarian can scan and issue your book.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: r.isPickupAvailable
                    ? () => setState(() => _page = 1)
                    : null,
                icon: const Icon(Icons.qr_code_rounded, size: 20),
                label: Text(r.isPickupAvailable
                    ? 'View pickup QR code'
                    : 'Pickup QR unavailable'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isRefreshing ? null : _refreshStatus,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh status'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Go to my bookings'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrPage() {
    final r = _reservation;
    final book = widget.book;

    return SingleChildScrollView(
      key: const ValueKey('qr'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GestureDetector(
              onTap: () => setState(() => _page = 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left_rounded,
                      size: 20, color: AppTheme.primaryGreen),
                  Text('Confirmation',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Pickup QR Code',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${book.title} · ${book.shelfLocation ?? "Desk"}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_added_rounded,
                      size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Show this QR code to the librarian to check out your reserved book.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // QR code card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
                  if (r.qrToken != null)
                    QrImageView(
                      data: r.qrToken!,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    )
                  else
                    const SizedBox(
                      height: 200,
                      child: Center(
                          child: Icon(Icons.qr_code_2_rounded,
                              size: 80, color: AppTheme.textMuted)),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Show this code to the desk scanner',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOLD STATUS',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _statusDescription(r),
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_statusLabel(r),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.isPickupAvailable
                        ? 'Expires on ${_monthName(r.holdExpiresAt.month)} ${r.holdExpiresAt.day}'
                        : r.isHoldExpired
                            ? 'This hold has expired'
                            : 'Last updated ${_formatDate(r.updatedAt ?? r.createdAt)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Go to my bookings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _statusLabel(BookReservation reservation) {
    switch (reservation.status) {
      case BookReservationStatus.reserved:
        return 'Held';
      case BookReservationStatus.borrowed:
        return 'Borrowed';
      case BookReservationStatus.returned:
        return 'Returned';
      case BookReservationStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _statusDescription(BookReservation reservation) {
    switch (reservation.status) {
      case BookReservationStatus.reserved:
        return 'Ready for pickup';
      case BookReservationStatus.borrowed:
        return 'Checked out';
      case BookReservationStatus.returned:
        return 'Returned to library';
      case BookReservationStatus.cancelled:
        return 'Reservation cancelled';
    }
  }

  String _formatDate(DateTime date) =>
      '${_monthName(date.month)} ${date.day}, ${date.year}';
}
