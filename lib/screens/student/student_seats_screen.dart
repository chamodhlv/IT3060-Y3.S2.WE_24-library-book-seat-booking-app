import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../services/seat_service.dart';
import '../shared/notifications_screen.dart';
import 'seat_detail_screen.dart';

/// Student: Seat availability overview screen.
class StudentSeatsScreen extends StatefulWidget {
  const StudentSeatsScreen({super.key});

  @override
  State<StudentSeatsScreen> createState() => _StudentSeatsScreenState();
}

class _StudentSeatsScreenState extends State<StudentSeatsScreen> {
  SeatSection _selectedSection = SeatSection.mainHall;
  List<Seat> _seats = [];
  Map<String, bool> _availability = {}; // seatId -> hasAvailability
  bool _isLoading = true;
  late List<DateTime> _days;
  int _selectedDayIndex = 0;
  DateTime _lastSync = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(4, (i) => today.add(Duration(days: i)));
    // If today's operating hours are already past (>= 17:00 = 5 PM), default to Tomorrow (index 1)
    if (now.hour >= 17) {
      _selectedDayIndex = 1;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await SeatService().expireOldBookings();
      final seats = await SeatService().getSeats(section: _selectedSection);
      final avail = await SeatService().getSeatAvailabilityForDate(_days[_selectedDayIndex]);
      setState(() {
        _seats = seats;
        _availability = avail;
        _lastSync = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _syncLabel() {
    final diff = DateTime.now().difference(_lastSync);
    if (diff.inSeconds < 10) return 'last synced just now';
    if (diff.inSeconds < 60) return 'last synced ${diff.inSeconds}s ago';
    return 'last synced ${diff.inMinutes}m ago';
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
            _buildDayPicker(),
            _buildSectionTabs(),
            Expanded(child: _buildBody()),
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
                  'Seat availability',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live · ${_syncLabel()}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _load,
                      child: const Icon(Icons.refresh_rounded,
                          size: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildNotificationBell(),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return IconButton(
      icon: const Icon(Icons.notifications_outlined),
      color: AppTheme.textPrimary,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        );
      },
      tooltip: 'Notifications',
    );
  }

  Widget _buildDayPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
            color: Colors.white,
          ),
          child: Row(
            children: List.generate(_days.length, (i) {
              final d = _days[i];
              final isSelected = i == _selectedDayIndex;
              final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
              final label = i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : dayNames[d.weekday - 1]);
              final dateLabel = '${d.day} ${monthNames[d.month - 1]}';

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDayIndex = i);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                            fontSize: 12,
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

  Widget _buildSectionTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _buildTab(SeatSection.mainHall),
          const SizedBox(width: 8),
          _buildTab(SeatSection.groupPods),
        ],
      ),
    );
  }

  Widget _buildTab(SeatSection section) {
    final isSelected = _selectedSection == section;
    return GestureDetector(
      onTap: () {
        if (_selectedSection == section) return;
        setState(() => _selectedSection = section);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryDark : AppTheme.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          section.displayName,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryDark),
      );
    }

    if (_seats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat_outlined,
                size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No seats in this section',
                style: GoogleFonts.inter(
                    fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedSection == SeatSection.mainHall)
              _buildMainHallGrid()
            else
              _buildGroupPodsGrid(),
            const SizedBox(height: 16),
            _buildLegend(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Tap any seat to view time slots & book',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHallGrid() {
    // 5x5 grid layout
    final rows = <List<Seat>>[];
    for (int i = 0; i < _seats.length; i += 5) {
      rows.add(_seats.sublist(i, (i + 5).clamp(0, _seats.length)));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: row.map((seat) => _buildSeatTile(seat)).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupPodsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _seats.length,
      itemBuilder: (ctx, i) => _buildSeatTile(_seats[i], isPod: true),
    );
  }

  Widget _buildSeatTile(Seat seat, {bool isPod = false}) {
    final hasAvailability = _availability[seat.id] ?? true;
    final availColor = const Color(0xFF4A7C68); // dark green
    final occupiedColor = const Color(0xFFE8A09A); // rose

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeatDetailScreen(
              seat: seat,
              initialDayIndex: _selectedDayIndex,
            ),
          ),
        ).then((_) => _load());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isPod ? null : 52,
        height: isPod ? null : 52,
        decoration: BoxDecoration(
          color: hasAvailability ? availColor : occupiedColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            seat.label,
            style: GoogleFonts.inter(
              fontSize: isPod ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(const Color(0xFF4A7C68), 'Free (Available slots)'),
        const SizedBox(width: 16),
        _legendDot(const Color(0xFFE8A09A), 'Fully booked'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }
}
