import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';

/// Two-screen combined booking confirmation + QR check-in screen.
class BookingConfirmationScreen extends StatefulWidget {
  final SeatBooking booking;
  final Seat seat;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.seat,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
  // 0 = confirmation, 1 = QR check-in
  int _page = 0;

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
    final b = widget.booking;
    final seat = widget.seat;

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
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 24),
        Text(
          'Seat booked!',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${seat.label} is reserved for you ${b.isToday ? 'today' : b.isTomorrow ? 'tomorrow' : ''}\nfrom ${b.timeRangeDisplay}.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),
        // Detail card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: [
                _detailRow('Location', '${seat.label} · ${seat.section.displayName}'),
                const Divider(height: 1, color: AppTheme.divider),
                _detailRow('Time', '${b.timeRangeDisplay}, ${b.isToday ? 'Today' : ''}'),
                const Divider(height: 1, color: AppTheme.divider),
                _detailRow(
                  'Check-in window',
                  'Opens ${_formatHour(b.startHour - 1 >= 0 ? b.startHour : b.startHour)}:45 ${b.startHour >= 12 ? 'PM' : 'AM'}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Remember to check in within 15 minutes of your slot starting, or the seat will be released automatically.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _page = 1),
                child: const Text('View check-in QR code'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  // Pop back to shells
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
    final b = widget.booking;
    final seat = widget.seat;
    final now = DateTime.now();
    final releaseTime = b.autoReleaseTime;
    final minutesLeft = releaseTime.difference(now).inMinutes;

    return SingleChildScrollView(
      key: const ValueKey('qr'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GestureDetector(
              onTap: () => setState(() => _page = 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left_rounded,
                      size: 20, color: AppTheme.primaryGreen),
                  Text('Seats',
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
                  'Check in to your seat',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${seat.label} · ${seat.section.displayName}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.primaryGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Warning banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: AppTheme.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check in within 15 minutes of ${b.timeRangeDisplay.split(' – ')[0]} or this seat will be released.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.errorRed),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // QR code
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  if (b.qrToken != null)
                    QrImageView(
                      data: b.qrToken!,
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
                  Text('STATUS',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Awaiting check-in',
                        style: GoogleFonts.inter(
                            fontSize: 16,
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
                        child: Text('Held',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E))),
                      ),
                    ],
                  ),
                  if (b.isToday && minutesLeft > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-release in ${minutesLeft}m if not checked in',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
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
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  String _formatHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }
}
