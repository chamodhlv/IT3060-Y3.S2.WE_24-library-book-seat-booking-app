import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../services/seat_service.dart';
import '../../services/auth_service.dart';
import 'booking_confirmation_screen.dart';

/// Student: Seat detail — choose a day and time slots.
class SeatDetailScreen extends StatefulWidget {
  final Seat seat;
  final int initialDayIndex;

  const SeatDetailScreen({
    super.key,
    required this.seat,
    this.initialDayIndex = 0,
  });

  @override
  State<SeatDetailScreen> createState() => _SeatDetailScreenState();
}

class _SeatDetailScreenState extends State<SeatDetailScreen> {
  // Days: today + 3
  late List<DateTime> _days;
  int _selectedDayIndex = 0;
  Set<int> _bookedHours = {};
  Set<int> _selectedHours = {};
  bool _reminderEnabled = false;
  bool _isLoading = true;
  bool _isBooking = false;

  static const int _openHour = 8;  // 8 AM
  static const int _closeHour = 17; // 5 PM (last slot 4–5 PM = hour 16)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(4, (i) => today.add(Duration(days: i)));
    _selectedDayIndex = widget.initialDayIndex.clamp(0, _days.length - 1);
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _isLoading = true;
      _selectedHours = {};
    });
    try {
      final booked = await SeatService()
          .getBookedHours(widget.seat.id, _days[_selectedDayIndex]);
      setState(() {
        _bookedHours = booked;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  /// Handle tapping a time slot.
  void _onSlotTap(int hour) {
    final selectedDate = _days[_selectedDayIndex];
    final now = DateTime.now();
    final slotStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour);

    if (_bookedHours.contains(hour) || slotStart.isBefore(now)) return;

    setState(() {
      if (_selectedHours.contains(hour)) {
        // Deselect — but only allow deselecting from the edge
        if (hour == _selectedHours.reduce((a, b) => a < b ? a : b) ||
            hour == _selectedHours.reduce((a, b) => a > b ? a : b)) {
          _selectedHours.remove(hour);
        } else {
          // Deselecting from middle not allowed — clear all
          _selectedHours.clear();
        }
      } else if (_selectedHours.isEmpty) {
        _selectedHours.add(hour);
      } else {
        // Only allow consecutive slots
        final minH = _selectedHours.reduce((a, b) => a < b ? a : b);
        final maxH = _selectedHours.reduce((a, b) => a > b ? a : b);

        // Check if the new hour is adjacent
        if (hour == minH - 1 || hour == maxH + 1) {
          // Check no booked or past hours in the range
          final rangeMin = (hour < minH) ? hour : minH;
          final rangeMax = (hour > maxH) ? hour : maxH;
          bool hasConflict = false;
          for (int h = rangeMin; h <= rangeMax; h++) {
            final hStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, h);
            if (_bookedHours.contains(h) || hStart.isBefore(now)) {
              hasConflict = true;
              break;
            }
          }
          if (!hasConflict) {
            _selectedHours.add(hour);
          }
        } else {
          // Non-adjacent: restart selection
          _selectedHours = {hour};
        }
      }
    });
  }

  String _formatHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }

  String get _selectionLabel {
    if (_selectedHours.isEmpty) return '';
    final sorted = _selectedHours.toList()..sort();
    final start = _formatHour(sorted.first);
    final end = _formatHour(sorted.last + 1);
    final hours = sorted.length;
    return 'Selected: $start – $end ($hours hr${hours > 1 ? 's' : ''})';
  }

  Future<void> _confirmBooking() async {
    if (_selectedHours.isEmpty) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    final selectedDate = _days[_selectedDayIndex];
    final now = DateTime.now();

    for (final hour in _selectedHours) {
      final slotStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour);
      if (slotStart.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot book a time slot in the past.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        _loadSlots();
        return;
      }
    }

    setState(() => _isBooking = true);

    try {
      final sorted = _selectedHours.toList()..sort();
      final booking = await SeatService().createBooking(
        seatId: widget.seat.id,
        userId: user.id,
        date: _days[_selectedDayIndex],
        startHour: sorted.first,
        endHour: sorted.last + 1,
        reminderEnabled: _reminderEnabled,
      );

      // Create notification
      await SeatService().createNotification(
        userId: user.id,
        title: 'Booking Confirmed 🎉',
        body:
            'Your seat ${widget.seat.label} is booked for ${_formatHour(sorted.first)} – ${_formatHour(sorted.last + 1)}.',
        type: 'booking_confirmed',
        relatedBookingId: booking.id,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(
            booking: booking,
            seat: widget.seat,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isBooking = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDayPicker(),
                    _buildSlotList(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left_rounded, size: 20,
                    color: AppTheme.primaryGreen),
                Text('Seats',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.seat.label} · ${widget.seat.section.displayName}',
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          if (widget.seat.featuresDisplay.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.seat.featuresDisplay,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'CHOOSE A DAY',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.2),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: List.generate(_days.length, (i) {
              final d = _days[i];
              final isSelected = i == _selectedDayIndex;
              final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
              final label = i == 0 ? 'Today' : dayNames[d.weekday - 1];
              final dateLabel = '${d.day} ${monthNames[d.month - 1]}';

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDayIndex = i);
                    _loadSlots();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryDark : null,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white70
                                : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'Available times for ${widget.seat.label}',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryDark)),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: List.generate(
                _closeHour - _openHour,
                (i) {
                  final hour = _openHour + i;
                  return _buildSlotRow(hour, isLast: i == _closeHour - _openHour - 1);
                },
              ),
            ),
          ),
        if (_selectedHours.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap consecutive available slots to build your session. $_selectionLabel',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Tap consecutive available slots to build your session.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        // Reminder toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Remind me 10 min before',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              Switch(
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
                activeThumbColor: AppTheme.primaryGreen,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSlotRow(int hour, {bool isLast = false}) {
    final isBooked = _bookedHours.contains(hour);
    final isSelected = _selectedHours.contains(hour);
    final selectedDate = _days[_selectedDayIndex];
    final now = DateTime.now();
    final slotStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour);
    final isPast = slotStart.isBefore(now);
    final label = '${_formatHour(hour)}–${_formatHour(hour + 1)}';

    Color bgColor = Colors.transparent;
    Color textColor = AppTheme.textPrimary;
    String statusText = 'Available';
    Color statusBg = const Color(0xFFDCFCE7);
    Color statusText2 = const Color(0xFF16A34A);

    if (isPast) {
      statusText = 'Past';
      statusBg = const Color(0xFFF3F4F6);
      statusText2 = AppTheme.textMuted;
      textColor = AppTheme.textMuted;
    } else if (isBooked) {
      statusText = 'Booked';
      statusBg = const Color(0xFFFFE4E4);
      statusText2 = AppTheme.errorRed;
    } else if (isSelected) {
      bgColor = AppTheme.primaryDark;
      textColor = Colors.white;
      statusText = 'Selected';
      statusBg = AppTheme.primaryDark;
      statusText2 = Colors.white;
    }

    final isInteractive = !isBooked && !isPast;

    return GestureDetector(
      onTap: isInteractive ? () => _onSlotTap(hour) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: isLast ? const BorderRadius.only(
            bottomLeft: Radius.circular(11),
            bottomRight: Radius.circular(11),
          ) : BorderRadius.zero,
          border: !isLast
              ? const Border(bottom: BorderSide(color: AppTheme.divider))
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.15) : statusBg,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                    : null,
              ),
              child: Text(
                statusText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : statusText2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final canBook = _selectedHours.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: canBook && !_isBooking ? _confirmBooking : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canBook ? AppTheme.primaryDark : AppTheme.divider,
          foregroundColor: Colors.white,
        ),
        child: _isBooking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                canBook ? 'Confirm booking · $_selectionLabel'.split(' · ')[1] : 'Select time slots',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
