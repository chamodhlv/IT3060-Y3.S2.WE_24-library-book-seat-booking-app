import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/book_model.dart';
import '../../services/book_service.dart';

/// Student: Browse the library catalogue (read-only).
class StudentBooksScreen extends StatefulWidget {
  const StudentBooksScreen({super.key});

  @override
  State<StudentBooksScreen> createState() => _StudentBooksScreenState();
}

class _StudentBooksScreenState extends State<StudentBooksScreen> {
  List<Book> _books = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedGenre; // null = all genres
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  static const List<Color> _avatarColors = [
    Color(0xFF1E2D3D),
    Color(0xFF5B8A72),
    Color(0xFF3B5998),
    Color(0xFF6B4226),
    Color(0xFF8E44AD),
    Color(0xFF2E86C1),
    Color(0xFF1A7A4A),
    Color(0xFFB7473A),
  ];

  Color _avatarColor(int index) => _avatarColors[index % _avatarColors.length];

  List<Book> get _filtered {
    var list = _books;
    if (_selectedGenre != null) {
      list = list.where((b) => b.genre == _selectedGenre).toList();
    }
    return list;
  }

  List<String> get _genres {
    final set = <String>{};
    for (final b in _books) {
      if (b.genre != null && b.genre!.isNotEmpty) set.add(b.genre!);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final books = await BookService()
          .getBooks(search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load books. Please try again later.\n\nError: $e';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchQuery = value);
      _load();
    });
  }

  // ─── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (!_isLoading && _errorMessage == null && _books.isNotEmpty)
              _buildGenreFilter(),
            _buildCountLabel(),
            Expanded(
              child: _isLoading
                  ? _buildLoader()
                  : _errorMessage != null
                      ? _buildError()
                      : _buildBookList(),
            ),
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
          Text(
            'Library Catalogue',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            'Browse and find available books',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by title, author, genre...',
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppTheme.textMuted, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 18),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreFilter() {
    final genres = _genres;
    if (genres.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        children: [
          _GenreChip(
            label: 'All',
            isSelected: _selectedGenre == null,
            onTap: () => setState(() => _selectedGenre = null),
          ),
          ...genres.map((g) => _GenreChip(
                label: g,
                isSelected: _selectedGenre == g,
                onTap: () =>
                    setState(() => _selectedGenre = g == _selectedGenre ? null : g),
              )),
        ],
      ),
    );
  }

  Widget _buildCountLabel() {
    final count = _filtered.length;
    final total = _books.length;
    final label = _selectedGenre != null
        ? '$count of $total books'
        : '${_books.where((b) => b.isActive).length} books available';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryDark));
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load catalogue',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'The library catalogue is not available right now. Please try again later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _load,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Try Again',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList() {
    final books = _filtered;

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isEmpty && _selectedGenre == null
                  ? 'No books available'
                  : 'No results found',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty && _selectedGenre == null
                  ? 'The library catalogue is empty.'
                  : 'Try a different search or genre filter.',
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryDark,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _buildBookCard(books[i], i),
      ),
    );
  }

  Widget _buildBookCard(Book book, int index) {
    final color = _avatarColor(index);

    return GestureDetector(
      onTap: () => _openDetailSheet(book, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  book.initials,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authors,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _CopiesBadge(book: book),
                        if (book.shelfLocation != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            book.shelfLocation!,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textMuted.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetailSheet(Book book, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentBookDetailSheet(
        book: book,
        avatarColor: _avatarColor(index),
      ),
    );
  }
}

// ─── STUDENT BOOK DETAIL SHEET ────────────────────────────────────────────────

class _StudentBookDetailSheet extends StatelessWidget {
  final Book book;
  final Color avatarColor;

  const _StudentBookDetailSheet(
      {required this.book, required this.avatarColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          book.initials,
                          style: GoogleFonts.inter(
                            fontSize: 18,
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
                              book.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              book.authors,
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
                  const SizedBox(height: 16),

                  // Availability banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: book.hasAvailableCopy
                          ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                          : AppTheme.errorRed.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: book.hasAvailableCopy
                            ? AppTheme.primaryGreen.withValues(alpha: 0.25)
                            : AppTheme.errorRed.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          book.hasAvailableCopy
                              ? Icons.check_circle_outline_rounded
                              : Icons.cancel_outlined,
                          size: 20,
                          color: book.hasAvailableCopy
                              ? AppTheme.primaryGreen
                              : AppTheme.errorRed,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.hasAvailableCopy
                                  ? 'Available to borrow'
                                  : 'Currently unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: book.hasAvailableCopy
                                    ? AppTheme.primaryGreen
                                    : AppTheme.errorRed,
                              ),
                            ),
                            Text(
                              '${book.availableCopies} of ${book.totalCopies} ${book.totalCopies == 1 ? 'copy' : 'copies'} on shelf',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: book.hasAvailableCopy
                                    ? AppTheme.primaryGreen.withValues(alpha: 0.8)
                                    : AppTheme.errorRed.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        if (book.genre != null)
                          _DetailRow(label: 'Genre', value: book.genre!),
                        if (book.isbn != null)
                          _DetailRow(label: 'ISBN', value: book.isbn!),
                        if (book.publisher != null)
                          _DetailRow(
                              label: 'Publisher', value: book.publisher!),
                        if (book.publishedYear != null)
                          _DetailRow(
                              label: 'Year', value: '${book.publishedYear}'),
                        if (book.shelfLocation != null)
                          _DetailRow(
                              label: 'Shelf', value: book.shelfLocation!),
                        if (book.description != null &&
                            book.description!.isNotEmpty) ...[
                          const Divider(color: AppTheme.divider),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              book.description!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppTheme.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Visit the library front desk to borrow this book. Show your student ID.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SMALL HELPERS ───────────────────────────────────────────────────────────

class _CopiesBadge extends StatelessWidget {
  final Book book;
  const _CopiesBadge({required this.book});

  @override
  Widget build(BuildContext context) {
    final available = book.availableCopies > 0;
    final dot = available ? AppTheme.primaryGreen : AppTheme.errorRed;
    final bg = available
        ? AppTheme.primaryGreen.withValues(alpha: 0.10)
        : AppTheme.errorRed.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            available
                ? (book.availableCopies == 1 ? '1 copy' : '${book.availableCopies} copies')
                : 'Borrowed',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: available ? AppTheme.primaryGreen : AppTheme.errorRed),
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenreChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryDark : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
