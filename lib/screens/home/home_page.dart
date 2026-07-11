import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/app_shell_controller.dart';
import '../../controllers/bible_controller.dart';
import '../../models/bible_book.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/adaptive_layout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final FocusNode _searchFocus = FocusNode();
  bool _searchActive = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _searchActive = false;
    });
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService?>(context);
    final shellController = Provider.of<AppShellController?>(context);
    final bibleController = Provider.of<BibleController?>(context);
    final user = userService?.user ?? UserModel();
    final palette = _homePalette(context);

    final searchBar = _HomeSearchBar(
      controller: _searchController,
      focusNode: _searchFocus,
      palette: palette,
      onChanged: (v) => setState(() {
        _query = v.trim();
        _searchActive = v.trim().isNotEmpty;
      }),
      onClear: _clearSearch,
    );

    if (_searchActive) {
      final results = _buildSearchResults(
        context,
        query: _query,
        user: user,
        books: bibleController?.books ?? const <BibleBook>[],
        shellController: shellController,
        bibleController: bibleController,
        palette: palette,
      );
      return AdaptiveScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
          return Column(
            children: <Widget>[
              Padding(
                padding: layout.pagePadding.copyWith(bottom: 0),
                child: searchBar,
              ),
              Expanded(child: results),
            ],
          );
        },
      );
    }

    final hero = _HomeHeroCard(user: user);
    final quickActions = _QuickActionsCard(
      onOpenBible: shellController == null
          ? null
          : () => shellController.selectTab(AppShellController.bibleIndex),
      onOpenMusic: shellController == null
          ? null
          : () => shellController.selectTab(AppShellController.musicIndex),
      onOpenProfile: shellController == null
          ? null
          : () => shellController.selectTab(AppShellController.profileIndex),
    );
    final summary = _SummaryCard(user: user);
    const focusCard = _FocusCard();

    return AdaptiveScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        final contentPadding = layout.pagePadding;

        if (!layout.useTwoPane) {
          return ListView(
            padding: contentPadding.copyWith(top: 0),
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                    contentPadding.left, contentPadding.top, contentPadding.right, 0),
                child: searchBar,
              ),
              const SizedBox(height: 16),
              hero,
              const SizedBox(height: 16),
              quickActions,
              const SizedBox(height: 16),
              summary,
              const SizedBox(height: 16),
              focusCard,
            ],
          );
        }

        return Padding(
          padding: contentPadding.copyWith(top: 0),
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: contentPadding.top),
                child: searchBar,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: layout.splitPrimaryFlex,
                      child: ListView(
                        children: <Widget>[
                          hero,
                          SizedBox(height: layout.paneSpacing),
                          summary,
                        ],
                      ),
                    ),
                    SizedBox(width: layout.paneSpacing),
                    Expanded(
                      flex: layout.splitSecondaryFlex,
                      child: ListView(
                        children: <Widget>[
                          quickActions,
                          SizedBox(height: layout.paneSpacing),
                          const _FocusCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(
    BuildContext context, {
    required String query,
    required UserModel user,
    required List<BibleBook> books,
    required AppShellController? shellController,
    required BibleController? bibleController,
    required _HomePalette palette,
  }) {
    final q = query.toLowerCase();

    final matchedVerses = user.savedVerses.where((v) {
      return v.text.toLowerCase().contains(q) ||
          v.bookTitle.toLowerCase().contains(q) ||
          v.passageId.toLowerCase().contains(q) ||
          v.versionLabel.toLowerCase().contains(q);
    }).take(20).toList();

    final matchedBooks = books.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.fullTitle.toLowerCase().contains(q) ||
          b.abbreviation.toLowerCase().contains(q);
    }).take(10).toList();

    final hasResults = matchedVerses.isNotEmpty || matchedBooks.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_rounded, size: 48, color: palette.mutedText),
            const SizedBox(height: 12),
            Text(
              'No results for "$query"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.mutedText,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: <Widget>[
        if (matchedBooks.isNotEmpty) ...<Widget>[
          _SearchSectionHeader(
              icon: Icons.menu_book_rounded, label: 'Bible Books', palette: palette),
          const SizedBox(height: 8),
          ...matchedBooks.map((book) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HomeSearchResultTile(
                  icon: Icons.book_rounded,
                  title: book.title,
                  subtitle: '${book.chapterCount} chapters',
                  palette: palette,
                  onTap: () {
                    _clearSearch();
                    shellController?.selectTab(AppShellController.bibleIndex);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      bibleController?.openBook(book);
                    });
                  },
                ),
              )),
          const SizedBox(height: 16),
        ],
        if (matchedVerses.isNotEmpty) ...<Widget>[
          _SearchSectionHeader(
              icon: Icons.bookmark_rounded, label: 'Saved Verses', palette: palette),
          const SizedBox(height: 8),
          ...matchedVerses.map((verse) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HomeSearchResultTile(
                  icon: Icons.format_quote_rounded,
                  title: '${verse.bookTitle} ${verse.chapterNumber}:${verse.verseNumber}',
                  subtitle: verse.text.length > 100
                      ? '${verse.text.substring(0, 100)}…'
                      : verse.text,
                  palette: palette,
                  onTap: () {
                    _clearSearch();
                    shellController?.selectTab(AppShellController.profileIndex);
                  },
                ),
              )),
        ],
      ],
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _HomePalette palette;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: palette.tileBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadowHue.withValues(alpha: isDark ? 0.40 : 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.88),
            blurRadius: 0,
            spreadRadius: 1,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search songs, verses, Bible books…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: palette.accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final _HomePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: palette.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
        ),
      ],
    );
  }
}

class _HomeSearchResultTile extends StatelessWidget {
  const _HomeSearchResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _HomePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.tileBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.shadowHue.withValues(alpha: isDark ? 0.38 : 0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.88),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.tileIconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: palette.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            height: 1.4,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final palette = _homePalette(context);
    final greetingName =
        (user.name?.trim().isNotEmpty ?? false) ? user.name!.trim() : 'friend';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.heroShadow,
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: palette.heroShadow.withValues(alpha: 0.40),
            blurRadius: 60,
            spreadRadius: -8,
            offset: const Offset(0, 28),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.18),
            blurRadius: 0,
            spreadRadius: 1,
            offset: const Offset(-3, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Bible App',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to Bible App',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Good to see you, $greetingName. Keep reading, listening, and saving what matters most without the layout fighting the device.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onOpenBible,
    required this.onOpenMusic,
    required this.onOpenProfile,
  });

  final VoidCallback? onOpenBible;
  final VoidCallback? onOpenMusic;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final palette = _homePalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.tileBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Quick start',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Jump straight into reading, music, or saved content.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 18),
            _ActionTile(
              icon: Icons.menu_book_rounded,
              title: 'Read Bible',
              subtitle: 'Open books, chapters, and the immersive reader.',
              onTap: onOpenBible,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.queue_music_rounded,
              title: 'Open Music',
              subtitle: 'Pick a playlist or continue your current track.',
              onTap: onOpenMusic,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.person_rounded,
              title: 'Profile & Saves',
              subtitle: 'Manage bookmarks, favorites, and preferences.',
              onTap: onOpenProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final palette = _homePalette(context);
    final summaryItems = <_SummaryItem>[
      _SummaryItem(label: 'Saved verses', value: user.savedVerses.length.toString()),
      _SummaryItem(label: 'Favorite songs', value: user.favoriteSongs.length.toString()),
      _SummaryItem(label: 'Folders', value: user.bookmarkCollections.length.toString()),
      _SummaryItem(
          label: 'Account',
          value: user.authStatus == AuthStatus.loggedIn ? 'Signed in' : 'Guest'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.tileBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your library at a glance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: summaryItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = summaryItems[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.panelBackground,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: palette.panelShadows,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: palette.accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: palette.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context) {
    final palette = _homePalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.tileBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today\'s focus',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Build one steady rhythm: read a chapter, save one verse, and keep a song ready offline for later.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 24),
            Text(
              'Responsive layouts are now tuned so this dashboard stays usable on phones, tablets, portrait, and landscape.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.mutedText,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _homePalette(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.panelBackground,
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.shadowHue.withValues(alpha: isDark ? 0.32 : 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.88),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.tileIconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: palette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePalette {
  const _HomePalette({
    required this.heroGradient,
    required this.heroShadow,
    required this.shadowHue,
    required this.panelBackground,
    required this.tileBackground,
    required this.tileIconBackground,
    required this.mutedText,
    required this.accent,
    required this.cardShadows,
    required this.panelShadows,
  });

  final List<Color> heroGradient;
  final Color heroShadow;
  final Color shadowHue;
  final Color panelBackground;
  final Color tileBackground;
  final Color tileIconBackground;
  final Color mutedText;
  final Color accent;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> panelShadows;
}

_HomePalette _homePalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return _HomePalette(
      heroGradient: const <Color>[Color(0xFF2A7C62), Color(0xFF143B30)],
      heroShadow: const Color(0xFF000000).withValues(alpha: 0.55),
      shadowHue: Colors.black,
      panelBackground: const Color(0xFF202B26),
      tileBackground: const Color(0xFF1C2621),
      tileIconBackground: const Color(0xFF263A32),
      mutedText: const Color(0xFFAAB7B0),
      accent: const Color(0xFF8FD8B5),
      cardShadows: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 22,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 44,
          spreadRadius: -6,
          offset: const Offset(0, 20),
        ),
        const BoxShadow(
          color: Color(0x0EFFFFFF),
          blurRadius: 0,
          spreadRadius: 1,
          offset: Offset(-2, -2),
        ),
      ],
      panelShadows: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
        const BoxShadow(
          color: Color(0x08FFFFFF),
          blurRadius: 0,
          spreadRadius: 1,
          offset: Offset(-1, -2),
        ),
      ],
    );
  }

  return _HomePalette(
    heroGradient: const <Color>[Color(0xFF1A5A47), Color(0xFF0F3F32)],
    heroShadow: const Color(0xFF0F3F32).withValues(alpha: 0.35),
    shadowHue: const Color(0xFF1A5A47),
    panelBackground: const Color(0xFFFAF5EC),
    tileBackground: const Color(0xFFFFFCF7),
    tileIconBackground: const Color(0xFFE3F0E9),
    mutedText: const Color(0xFF6C6A65),
    accent: const Color(0xFF195241),
    cardShadows: <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF1A5A47).withValues(alpha: 0.22),
        blurRadius: 22,
        offset: const Offset(0, 9),
      ),
      BoxShadow(
        color: const Color(0xFF1A5A47).withValues(alpha: 0.10),
        blurRadius: 44,
        spreadRadius: -6,
        offset: const Offset(0, 20),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.90),
        blurRadius: 0,
        spreadRadius: 2,
        offset: const Offset(-3, -3),
      ),
    ],
    panelShadows: <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF1A5A47).withValues(alpha: 0.14),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.92),
        blurRadius: 0,
        spreadRadius: 1,
        offset: const Offset(-2, -2),
      ),
    ],
  );
}

class _SummaryItem {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;
}
