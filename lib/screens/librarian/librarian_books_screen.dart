import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../models/book_model.dart';
import '../../services/book_service.dart';

/// Librarian: Full book catalogue management with CRUD operations.
class LibrarianBooksScreen extends StatefulWidget {
  const LibrarianBooksScreen({super.key});

  @override
  State<LibrarianBooksScreen> createState() => _LibrarianBooksScreenState();
}

class _LibrarianBooksScreenState extends State<LibrarianBooksScreen>
    with SingleTickerProviderStateMixin {
  List<Book> _books = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Avatar color palette cycling through a fixed list
  static const List<Color> _avatarColors = [
    Color(0xFF12254E), // primaryDark
    Color(0xFF5B8A72), // primaryGreen
    Color(0xFF3B5998),
    Color(0xFF6B4226),
    Color(0xFF8E44AD),
    Color(0xFF2E86C1),
    Color(0xFF1A7A4A),
    Color(0xFFB7473A),
  ];

  Color _avatarColor(int index) => _avatarColors[index % _avatarColors.length];

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
          .getAllBooks(search: _searchQuery.isEmpty ? null : _searchQuery);
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load books.\n\nPlease run books_setup.sql in your Supabase SQL Editor first.\n\nError: $e';
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
    final activeCount = _books.where((b) => b.isActive).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(activeCount),
            _buildSearchBar(),
            _buildCatalogueLabel(activeCount),
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
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader(int count) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Librarian Panel',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'Admin Catalogue & Stock Controls',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
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
            hintText: 'Search by book ID, title, or shelf...',
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

  Widget _buildCatalogueLabel(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        'ACTIVE CATALOGUE ($count BOOKS)',
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
              child: const Icon(Icons.warning_amber_rounded,
                  size: 40, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 16),
            Text(
              'Books table not set up',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Run books_setup.sql in your Supabase SQL Editor to create the table and seed sample data.',
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
                child: Text('Retry',
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
    if (_books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 56,
                color: AppTheme.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isEmpty ? 'No books in catalogue' : 'No results found',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? 'Tap the + button to add your first book.'
                  : 'Try a different search term.',
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        itemCount: _books.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _buildBookCard(_books[i], i),
      ),
    );
  }

  Widget _buildBookCard(Book book, int index) {
    final color = _avatarColor(index);
    final isUnavailable = !book.hasAvailableCopy;

    return GestureDetector(
      onTap: () => _openDetailSheet(book, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnavailable
                ? AppTheme.errorRed.withValues(alpha: 0.15)
                : AppTheme.divider,
          ),
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
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Copies pill
                        _buildCopiesPill(book),
                        if (book.shelfLocation != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            book.shelfLocation!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chevron
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.textMuted.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopiesPill(Book book) {
    Color dotColor;
    Color bgColor;
    Color textColor;

    if (!book.isActive) {
      dotColor = AppTheme.textMuted;
      bgColor = AppTheme.textMuted.withValues(alpha: 0.1);
      textColor = AppTheme.textMuted;
    } else if (book.availableCopies == 0) {
      dotColor = AppTheme.errorRed;
      bgColor = AppTheme.errorRed.withValues(alpha: 0.08);
      textColor = AppTheme.errorRed;
    } else {
      dotColor = AppTheme.primaryGreen;
      bgColor = AppTheme.primaryGreen.withValues(alpha: 0.1);
      textColor = AppTheme.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            !book.isActive
                ? 'Inactive'
                : book.availableCopies == 0
                    ? 'Borrowed'
                    : book.copiesLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _openAddBookSheet,
      backgroundColor: AppTheme.primaryDark,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      label: Text(
        'Add Book',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  // ─── SHEETS ───────────────────────────────────────────────────

  void _openAddBookSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookFormSheet(
        onSave: (data) async {
          try {
            await BookService().createBook(
              title: data['title'],
              authors: data['authors'],
              isbn: data['isbn'],
              publisher: data['publisher'],
              publishedYear: data['publishedYear'],
              genre: data['genre'],
              description: data['description'],
              shelfLocation: data['shelfLocation'],
              totalCopies: data['totalCopies'],
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Book added successfully.',
                      style: GoogleFonts.inter()),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
              _load();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e', style: GoogleFonts.inter()),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _openDetailSheet(Book book, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookDetailSheet(
        book: book,
        avatarColor: _avatarColor(index),
        onEdit: () {
          Navigator.pop(context);
          _openEditSheet(book);
        },
        onAddCopies: () {
          Navigator.pop(context);
          _openAddCopiesDialog(book);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(book);
        },
      ),
    );
  }

  void _openEditSheet(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookFormSheet(
        existingBook: book,
        onSave: (data) async {
          try {
            await BookService().updateBook(
              id: book.id,
              title: data['title'],
              authors: data['authors'],
              isbn: data['isbn'],
              publisher: data['publisher'],
              publishedYear: data['publishedYear'],
              genre: data['genre'],
              description: data['description'],
              shelfLocation: data['shelfLocation'],
              totalCopies: data['totalCopies'],
              availableCopies: data['availableCopies'],
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Book updated successfully.',
                      style: GoogleFonts.inter()),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
              _load();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e', style: GoogleFonts.inter()),
                  backgroundColor: AppTheme.errorRed,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _openAddCopiesDialog(Book book) {
    int copiesToAdd = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Copies',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                book.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Current: ${book.totalCopies} total · ${book.availableCopies} available',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CopyCountButton(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      if (copiesToAdd > 1) setS(() => copiesToAdd--);
                    },
                  ),
                  Container(
                    width: 64,
                    alignment: Alignment.center,
                    child: Text(
                      '$copiesToAdd',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _CopyCountButton(
                    icon: Icons.add_rounded,
                    onTap: () => setS(() => copiesToAdd++),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'copies to add',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await BookService()
                      .addCopies(id: book.id, copiesToAdd: copiesToAdd);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '$copiesToAdd ${copiesToAdd == 1 ? 'copy' : 'copies'} added.',
                            style: GoogleFonts.inter()),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e', style: GoogleFonts.inter()),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                minimumSize: const Size(80, 40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Add', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Book',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text(
            'Are you sure you want to permanently delete "${book.title}"? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await BookService().deleteBook(book.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('"${book.title}" deleted.', style: GoogleFonts.inter()),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.inter()),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}

// ─── BOOK DETAIL SHEET ────────────────────────────────────────────────────────

class _BookDetailSheet extends StatelessWidget {
  final Book book;
  final Color avatarColor;
  final VoidCallback onEdit;
  final VoidCallback onAddCopies;
  final VoidCallback onDelete;

  const _BookDetailSheet({
    required this.book,
    required this.avatarColor,
    required this.onEdit,
    required this.onAddCopies,
    required this.onDelete,
  });

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
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
                  const SizedBox(height: 20),

                  // Copies summary card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            label: 'Total Copies',
                            value: '${book.totalCopies}',
                            icon: Icons.library_books_outlined,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        Container(
                            width: 1, height: 40, color: AppTheme.divider),
                        Expanded(
                          child: _StatItem(
                            label: 'Available',
                            value: '${book.availableCopies}',
                            icon: Icons.check_circle_outline_rounded,
                            color: book.hasAvailableCopy
                                ? AppTheme.primaryGreen
                                : AppTheme.errorRed,
                          ),
                        ),
                        Container(
                            width: 1, height: 40, color: AppTheme.divider),
                        Expanded(
                          child: _StatItem(
                            label: 'Borrowed',
                            value:
                                '${book.totalCopies - book.availableCopies}',
                            icon: Icons.person_outline_rounded,
                            color: AppTheme.warningAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details
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
                          _DetailRow(
                              label: 'Genre', value: book.genre!),
                        if (book.isbn != null)
                          _DetailRow(label: 'ISBN', value: book.isbn!),
                        if (book.publisher != null)
                          _DetailRow(
                              label: 'Publisher', value: book.publisher!),
                        if (book.publishedYear != null)
                          _DetailRow(
                              label: 'Year',
                              value: '${book.publishedYear}'),
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
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Add Copies',
                          color: AppTheme.primaryGreen,
                          onTap: onAddCopies,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit Book',
                          color: AppTheme.primaryDark,
                          onTap: onEdit,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: AppTheme.errorRed,
                        onTap: onDelete,
                        compact: true,
                      ),
                    ],
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

// ─── BOOK FORM SHEET ─────────────────────────────────────────────────────────

class _BookFormSheet extends StatefulWidget {
  final Book? existingBook;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _BookFormSheet({this.existingBook, required this.onSave});

  @override
  State<_BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends State<_BookFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorsCtrl;
  late final TextEditingController _isbnCtrl;
  late final TextEditingController _publisherCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _genreCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _shelfCtrl;
  late int _totalCopies;
  late int _availableCopies;

  bool get _isEditing => widget.existingBook != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBook;
    _titleCtrl = TextEditingController(text: b?.title ?? '');
    _authorsCtrl = TextEditingController(text: b?.authors ?? '');
    _isbnCtrl = TextEditingController(text: b?.isbn ?? '');
    _publisherCtrl = TextEditingController(text: b?.publisher ?? '');
    _yearCtrl =
        TextEditingController(text: b?.publishedYear?.toString() ?? '');
    _genreCtrl = TextEditingController(text: b?.genre ?? '');
    _descriptionCtrl = TextEditingController(text: b?.description ?? '');
    _shelfCtrl = TextEditingController(text: b?.shelfLocation ?? '');
    _totalCopies = b?.totalCopies ?? 1;
    _availableCopies = b?.availableCopies ?? 1;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorsCtrl.dispose();
    _isbnCtrl.dispose();
    _publisherCtrl.dispose();
    _yearCtrl.dispose();
    _genreCtrl.dispose();
    _descriptionCtrl.dispose();
    _shelfCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await widget.onSave({
      'title': _titleCtrl.text,
      'authors': _authorsCtrl.text,
      'isbn': _isbnCtrl.text.isEmpty ? null : _isbnCtrl.text,
      'publisher': _publisherCtrl.text.isEmpty ? null : _publisherCtrl.text,
      'publishedYear': _yearCtrl.text.isEmpty
          ? null
          : int.tryParse(_yearCtrl.text),
      'genre': _genreCtrl.text.isEmpty ? null : _genreCtrl.text,
      'description':
          _descriptionCtrl.text.isEmpty ? null : _descriptionCtrl.text,
      'shelfLocation': _shelfCtrl.text.isEmpty ? null : _shelfCtrl.text,
      'totalCopies': _totalCopies,
      'availableCopies': _availableCopies,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    _isEditing ? 'Edit Book' : 'Add New Book',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormField(
                        controller: _titleCtrl,
                        label: 'Book Title *',
                        hint: 'e.g. Clean Code',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _FormField(
                        controller: _authorsCtrl,
                        label: 'Author(s) *',
                        hint: 'e.g. Robert C. Martin',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Author is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _FormField(
                              controller: _isbnCtrl,
                              label: 'ISBN',
                              hint: '978-...',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FormField(
                              controller: _yearCtrl,
                              label: 'Year',
                              hint: '2023',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _FormField(
                              controller: _publisherCtrl,
                              label: 'Publisher',
                              hint: 'e.g. O\'Reilly',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FormField(
                              controller: _genreCtrl,
                              label: 'Genre',
                              hint: 'e.g. Computer Science',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _FormField(
                        controller: _shelfCtrl,
                        label: 'Shelf Location',
                        hint: 'e.g. Shelf A1',
                      ),
                      const SizedBox(height: 12),
                      _FormField(
                        controller: _descriptionCtrl,
                        label: 'Description',
                        hint: 'Brief synopsis...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Copies section
                      Text(
                        'Stock Management',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            _CopiesRow(
                              label: 'Total Copies',
                              sublabel: 'How many physical copies exist',
                              value: _totalCopies,
                              onDecrease: () {
                                if (_totalCopies > 1) {
                                  setState(() {
                                    _totalCopies--;
                                    if (_availableCopies > _totalCopies) {
                                      _availableCopies = _totalCopies;
                                    }
                                  });
                                }
                              },
                              onIncrease: () =>
                                  setState(() => _totalCopies++),
                            ),
                            if (_isEditing) ...[
                              const Divider(
                                  color: AppTheme.divider, height: 20),
                              _CopiesRow(
                                label: 'Available Copies',
                                sublabel: 'Copies currently on shelf',
                                value: _availableCopies,
                                onDecrease: () {
                                  if (_availableCopies > 0) {
                                    setState(() => _availableCopies--);
                                  }
                                },
                                onIncrease: () {
                                  if (_availableCopies < _totalCopies) {
                                    setState(() => _availableCopies++);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _isEditing ? 'Save Changes' : 'Add Book',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
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
}

// ─── SMALL WIDGETS ────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryDark, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.errorRed),
            ),
          ),
        ),
      ],
    );
  }
}

class _CopiesRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _CopiesRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _CopyCountButton(icon: Icons.remove_rounded, onTap: onDecrease),
            Container(
              width: 44,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            _CopyCountButton(icon: Icons.add_rounded, onTap: onIncrease),
          ],
        ),
      ],
    );
  }
}

class _CopyCountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CopyCountButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
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
            width: 84,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
