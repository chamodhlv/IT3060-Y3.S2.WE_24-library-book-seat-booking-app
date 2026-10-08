import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/seat_model.dart';
import '../../services/seat_service.dart';

/// Librarian: Seat management screen (CRUD).
class LibrarianSeatsScreen extends StatefulWidget {
  const LibrarianSeatsScreen({super.key});

  @override
  State<LibrarianSeatsScreen> createState() => _LibrarianSeatsScreenState();
}

class _LibrarianSeatsScreenState extends State<LibrarianSeatsScreen> {
  SeatSection _selectedSection = SeatSection.mainHall;
  List<Seat> _seats = [];
  Seat? _selectedSeat;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final seats =
          await SeatService().getAllSeats(section: _selectedSection);
      setState(() {
        _seats = seats;
        _selectedSeat =
            seats.isNotEmpty ? seats.first : null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryDark))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOperationsHeader(),
                  const SizedBox(height: 16),
                  _buildSectionTabs(),
                  const SizedBox(height: 16),
                  Text(
                    '${_selectedSection.displayName} Layout',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _buildSeatGrid(),
                  const SizedBox(height: 12),
                  _buildLegend(),
                  if (_selectedSeat != null) ...[
                    const SizedBox(height: 20),
                    _buildSeatDetails(_selectedSeat!),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(null),
        backgroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add New Seat',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildOperationsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_seat_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seat operations',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text('${_seats.length} seats in ${_selectedSection.displayName}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.divider),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: SeatSection.values.map((s) {
          final isSelected = _selectedSection == s;
          final count = _selectedSection == s ? _seats.length : null;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedSection = s);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryDark : null,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Center(
                  child: Text(
                    '${s.displayName}${count != null ? ' ($count)' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeatGrid() {
    if (_seats.isEmpty) {
      return Center(
        child: Text('No seats yet.',
            style:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted)),
      );
    }

    if (_selectedSection == SeatSection.mainHall) {
      return _buildMainHallGrid();
    } else {
      return _buildPodsGrid();
    }
  }

  Widget _buildMainHallGrid() {
    // 5-per-row grid
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
              children: row.map((seat) => _buildAdminSeatTile(seat)).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPodsGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: _seats.length,
        itemBuilder: (ctx, i) => _buildAdminSeatTile(_seats[i]),
      ),
    );
  }

  Widget _buildAdminSeatTile(Seat seat) {
    final isSelected = _selectedSeat?.id == seat.id;
    final isOccupied = !seat.isActive;
    Color bgColor;
    Color textColor;
    if (isOccupied) {
      bgColor = const Color(0xFFE8A09A);
      textColor = Colors.white;
    } else if (isSelected) {
      bgColor = AppTheme.primaryDark;
      textColor = Colors.white;
    } else {
      bgColor = const Color(0xFFB8D4C8);
      textColor = AppTheme.primaryDark;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedSeat = seat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            seat.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
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
        _dot(const Color(0xFFB8D4C8), 'Available'),
        const SizedBox(width: 14),
        _dot(const Color(0xFFE8A09A), 'Occupied'),
        const SizedBox(width: 14),
        _dot(AppTheme.primaryDark, 'Selected'),
      ],
    );
  }

  Widget _dot(Color c, String l) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(l,
            style:
                GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
      ]);

  Widget _buildSeatDetails(Seat seat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seat Details',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        Container(
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
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chair_outlined,
                          color: AppTheme.primaryGreen, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seat ${seat.label}',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          if (seat.featuresDisplay.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...seat.features.map((f) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 13,
                                        color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(_featureLabel(f),
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)),
                                  ]),
                                )),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                      value: seat.isActive,
                      onChanged: (v) async {
                        await SeatService().updateSeat(
                            seat.id, seat.copyWith(isActive: v));
                        _load();
                      },
                      activeThumbColor: AppTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.divider),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showAddEditDialog(seat),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                        ),
                        child: Text('Edit Seat',
                            style: GoogleFonts.inter(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _deleteSeat(seat),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteSeat(Seat seat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Seat ${seat.label}?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
            'This will permanently delete the seat and all associated bookings.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.inter(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm == true) {
      await SeatService().deleteSeat(seat.id);
      _load();
    }
  }

  void _showAddEditDialog(Seat? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SeatFormSheet(
        existing: existing,
        section: _selectedSection,
        onSaved: (seat) async {
          if (existing == null) {
            await SeatService().addSeat(seat);
          } else {
            await SeatService().updateSeat(existing.id, seat);
          }
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  String _featureLabel(String f) {
    const map = {
      'window_side': 'Window side',
      'power_outlet': 'Power outlet available',
      'individual_study_seat': 'Individual study seat',
      'group_study': 'Group study',
      'whiteboard': 'Whiteboard',
    };
    return map[f] ?? f;
  }
}

/// Bottom sheet form for adding/editing a seat.
class _SeatFormSheet extends StatefulWidget {
  final Seat? existing;
  final SeatSection section;
  final Future<void> Function(Seat seat) onSaved;

  const _SeatFormSheet({
    this.existing,
    required this.section,
    required this.onSaved,
  });

  @override
  State<_SeatFormSheet> createState() => _SeatFormSheetState();
}

class _SeatFormSheetState extends State<_SeatFormSheet> {
  late TextEditingController _labelCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _capacityCtrl;
  late List<String> _features;
  late bool _isActive;
  bool _saving = false;

  final List<String> _allFeatures = [
    'window_side',
    'power_outlet',
    'individual_study_seat',
    'group_study',
    'whiteboard',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _capacityCtrl = TextEditingController(
        text: (e?.capacity ?? (widget.section == SeatSection.groupPods ? 5 : 1))
            .toString());
    _features = List<String>.from(e?.features ?? []);
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  String _featureLabel(String f) {
    const map = {
      'window_side': 'Window side',
      'power_outlet': 'Power outlet',
      'individual_study_seat': 'Individual study seat',
      'group_study': 'Group study',
      'whiteboard': 'Whiteboard',
    };
    return map[f] ?? f;
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a seat label (e.g. A1, Pod 1)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final seat = Seat(
        id: widget.existing?.id ?? '',
        label: label,
        section: widget.section,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 1,
        features: _features,
        isActive: _isActive,
        sortOrder: widget.existing?.sortOrder ?? 0,
      );
      await widget.onSaved(seat);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save seat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? 'Add New Seat' : 'Edit Seat',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Seat Label (e.g. A1)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            const SizedBox(height: 16),
            Text('Features',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allFeatures.map((f) {
                final selected = _features.contains(f);
                return FilterChip(
                  label: Text(_featureLabel(f),
                      style: GoogleFonts.inter(fontSize: 12)),
                  selected: selected,
                  selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryGreen,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _features.add(f);
                      } else {
                        _features.remove(f);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: Text('Active',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              activeThumbColor: AppTheme.primaryGreen,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.existing == null ? 'Add Seat' : 'Save Changes',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
