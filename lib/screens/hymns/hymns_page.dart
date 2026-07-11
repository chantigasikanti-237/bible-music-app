import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/bible_languages.dart';
import '../../theme/clay_decorations.dart';
import '../../models/hymn.dart';
import '../../services/api_client.dart';
import '../../services/hymns_service.dart';
import '../../widgets/adaptive_layout.dart';

class HymnsPage extends StatefulWidget {
  const HymnsPage({super.key});

  @override
  State<HymnsPage> createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage> {
  static const int _pageSize = 50;

  final HymnsService _hymnsService = HymnsService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();

  List<Hymn> _songs = <Hymn>[];
  String? _selectedLanguageCode;
  String? _errorMessage;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _nextPage = 1;
  int _songNumberBase = 1;
  int _requestVersion = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _listScrollController.addListener(_handleScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _listScrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadFirstPage(),
    );
  }

  void _handleScroll() {
    if (!_listScrollController.hasClients ||
        _isInitialLoading ||
        _isLoadingMore ||
        !_hasNextPage) {
      return;
    }

    final position = _listScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 420) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    final requestVersion = ++_requestVersion;
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _hasNextPage = true;
      _nextPage = 1;
      _songNumberBase = 1;
    });

    final searchText = _searchController.text.trim();
    final songNumber = int.tryParse(searchText);

    if (songNumber != null && songNumber > 0) {
      // Number search: jump to the exact position in the sorted list.
      final targetPage = ((songNumber - 1) ~/ _pageSize) + 1;
      final indexInPage = (songNumber - 1) % _pageSize;

      try {
        final result = await _hymnsService.fetchSongs(
          page: targetPage,
          limit: _pageSize,
          languageCode: _selectedLanguageCode,
        );

        if (!mounted || requestVersion != _requestVersion) return;

        setState(() {
          _songs = indexInPage < result.songs.length
              ? <Hymn>[result.songs[indexInPage]]
              : <Hymn>[];
          _songNumberBase = songNumber;
          _hasNextPage = false;
          _isInitialLoading = false;
        });
      } on ApiException catch (error) {
        _handleFirstPageError(requestVersion, error.message);
      } catch (_) {
        _handleFirstPageError(requestVersion, 'Failed to load Hymns.');
      }
      return;
    }

    try {
      final result = await _hymnsService.fetchSongs(
        page: 1,
        limit: _pageSize,
        search: searchText.isEmpty ? null : searchText,
        languageCode: _selectedLanguageCode,
      );

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _songs = result.songs;
        _songNumberBase = 1;
        _nextPage = result.nextPage ?? result.page + 1;
        _hasNextPage = result.hasNextPage;
        _isInitialLoading = false;
      });
    } on ApiException catch (error) {
      _handleFirstPageError(requestVersion, error.message);
    } catch (error) {
      _handleFirstPageError(requestVersion, 'Failed to load Hymns.');
    }
  }

  void _handleFirstPageError(int requestVersion, String message) {
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    setState(() {
      _songs = <Hymn>[];
      _errorMessage = message;
      _isInitialLoading = false;
      _hasNextPage = false;
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasNextPage) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _hymnsService.fetchSongs(
        page: _nextPage,
        limit: _pageSize,
        search: _searchController.text,
        languageCode: _selectedLanguageCode,
      );

      if (!mounted) {
        return;
      }

      final existingIds = _songs.map((Hymn song) => song.id).toSet();
      final newSongs = result.songs
          .where((Hymn song) => !existingIds.contains(song.id))
          .toList(growable: false);

      setState(() {
        _songs = <Hymn>[..._songs, ...newSongs];
        _nextPage = result.nextPage ?? result.page + 1;
        _hasNextPage = result.hasNextPage;
        _isLoadingMore = false;
      });
    } on ApiException catch (error) {
      _handleLoadMoreError(error.message);
    } catch (_) {
      _handleLoadMoreError('Failed to load more hymns.');
    }
  }

  void _handleLoadMoreError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingMore = false;
    });
    showClaySnackBar(context, message, type: ClaySnackType.error);
  }

  Future<void> _refresh() async {
    await _loadFirstPage();
  }

  void _selectLanguage(String? languageCode) {
    if (_selectedLanguageCode == languageCode) {
      return;
    }
    setState(() {
      _selectedLanguageCode = languageCode;
    });
    _loadFirstPage();
  }

  void _openHymnDetails(Hymn song) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HymnsDetailsPage(song: song),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        return _HymnsListView(
          controller: _listScrollController,
          searchController: _searchController,
          songs: _songs,
          selectedSongId: null,
          selectedLanguageCode: _selectedLanguageCode,
          songNumberBase: _songNumberBase,
          isInitialLoading: _isInitialLoading,
          isLoadingMore: _isLoadingMore,
          hasNextPage: _hasNextPage,
          errorMessage: _errorMessage,
          padding: layout.pagePadding,
          onRefresh: _refresh,
          onRetry: _loadFirstPage,
          onSelectLanguage: _selectLanguage,
          onSongTap: _openHymnDetails,
        );
      },
    );
  }
}

class HymnsDetailsPage extends StatelessWidget {
  const HymnsDetailsPage({
    super.key,
    required this.song,
  });

  final Hymn song;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Hymns'),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      safeAreaTop: false,
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        return SingleChildScrollView(
          padding: layout.pagePadding,
          child: _HymnsReader(song: song),
        );
      },
    );
  }
}

class _HymnsListView extends StatelessWidget {
  const _HymnsListView({
    required this.controller,
    required this.searchController,
    required this.songs,
    required this.selectedSongId,
    required this.selectedLanguageCode,
    required this.songNumberBase,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasNextPage,
    required this.errorMessage,
    required this.onRefresh,
    required this.onRetry,
    required this.onSelectLanguage,
    required this.onSongTap,
    this.padding = EdgeInsets.zero,
  });

  final ScrollController controller;
  final TextEditingController searchController;
  final List<Hymn> songs;
  final String? selectedSongId;
  final String? selectedLanguageCode;
  final int songNumberBase;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasNextPage;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final ValueChanged<String?> onSelectLanguage;
  final ValueChanged<Hymn> onSongTap;
  final EdgeInsets padding;

  int get _bodyItemCount {
    if (isInitialLoading || errorMessage != null || songs.isEmpty) {
      return 1;
    }
    return songs.length + 1;
  }

  @override
  Widget build(BuildContext context) {
    const headerItemCount = 3;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: headerItemCount + _bodyItemCount,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _HymnsHeader(loadedCount: songs.length),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _HymnsSearchField(controller: searchController),
            );
          }
          if (index == 2) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _HymnsLanguageFilter(
                selectedLanguageCode: selectedLanguageCode,
                onSelectLanguage: onSelectLanguage,
              ),
            );
          }

          final bodyIndex = index - headerItemCount;
          if (isInitialLoading) {
            return const _HymnsLoadingState();
          }
          if (errorMessage != null) {
            return _HymnsStateMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Hymns unavailable',
              message: errorMessage!,
              actionLabel: 'Retry',
              onActionPressed: onRetry,
            );
          }
          if (songs.isEmpty) {
            return const _HymnsStateMessage(
              icon: Icons.search_off_rounded,
              title: 'No hymns found',
              message: 'Try another title or language.',
            );
          }
          if (bodyIndex == songs.length) {
            return _HymnsPaginationFooter(
              isLoadingMore: isLoadingMore,
              hasNextPage: hasNextPage,
            );
          }

          final song = songs[bodyIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HymnsTile(
              song: song,
              songNumber: songNumberBase + bodyIndex,
              selected: song.id == selectedSongId,
              onTap: () => onSongTap(song),
            ),
          );
        },
      ),
    );
  }
}

class _HymnsHeader extends StatelessWidget {
  const _HymnsHeader({
    required this.loadedCount,
  });

  final int loadedCount;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.headerGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: palette.headerShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.lyrics_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Hymns',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$loadedCount loaded',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w700,
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
}

class _HymnsSearchField extends StatelessWidget {
  const _HymnsSearchField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search_rounded),
        labelText: 'Search by title',
      ),
    );
  }
}

class _HymnsLanguageFilter extends StatelessWidget {
  const _HymnsLanguageFilter({
    required this.selectedLanguageCode,
    required this.onSelectLanguage,
  });

  final String? selectedLanguageCode;
  final ValueChanged<String?> onSelectLanguage;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    final chips = <Widget>[
      _HymnsFilterChip(
        label: 'All',
        selected: selectedLanguageCode == null,
        onSelected: () => onSelectLanguage(null),
      ),
      for (final language in bibleLanguageOptions)
        _HymnsFilterChip(
          label: language.englishLabel,
          selected: selectedLanguageCode == language.code,
          onSelected: () => onSelectLanguage(language.code),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.readerBackground,
        borderRadius: BorderRadius.circular(22),
        boxShadow: palette.cardShadows,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: chips
              .map(
                (Widget chip) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: chip,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _HymnsFilterChip extends StatelessWidget {
  const _HymnsFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: palette.selectedTileBackground,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? palette.accent : palette.mutedText,
            fontWeight: FontWeight.w800,
          ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _HymnsTile extends StatelessWidget {
  const _HymnsTile({
    required this.song,
    required this.songNumber,
    required this.selected,
    required this.onTap,
  });

  final Hymn song;
  final int songNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? palette.selectedTileBackground : palette.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: selected ? palette.tileShadows : palette.cardShadows,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? palette.accent.withValues(alpha: 0.16)
                      : palette.iconBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$songNumber',
                  style: TextStyle(
                    color: selected ? palette.accent : palette.mutedText,
                    fontWeight: FontWeight.w800,
                    fontSize: songNumber >= 1000 ? 11 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: selected ? palette.accent : null,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _languageLabel(song.languageCode),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _HymnsReader extends StatelessWidget {
  const _HymnsReader({
    required this.song,
  });

  final Hymn? song;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    final selectedSong = song;

    if (selectedSong == null) {
      return const _HymnsStateMessage(
        icon: Icons.lyrics_rounded,
        title: 'Hymns',
        message: '',
      );
    }

    final sections = selectedSong.lyricsSections;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.readerBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: palette.iconBackground,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(Icons.menu_book_rounded, color: palette.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        selectedSong.title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _languageLabel(selectedSong.languageCode),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: palette.mutedText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (sections.isEmpty)
              const _HymnsStateMessage(
                icon: Icons.notes_rounded,
                title: 'Lyrics pending',
                message: 'This hymn does not include lyrics yet.',
              )
            else
              ...sections.map(
                (HymnLyricsSection section) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _LyricsSectionBlock(section: section),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LyricsSectionBlock extends StatelessWidget {
  const _LyricsSectionBlock({
    required this.section,
  });

  final HymnLyricsSection section;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    final label = section.label?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null && label.isNotEmpty) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.iconBackground,
              borderRadius: BorderRadius.circular(999),
              boxShadow: palette.tileShadows,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SelectableText(
          section.text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.72,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _HymnsPaginationFooter extends StatelessWidget {
  const _HymnsPaginationFooter({
    required this.isLoadingMore,
    required this.hasNextPage,
  });

  final bool isLoadingMore;
  final bool hasNextPage;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: clayLoadingCenter(context),
      );
    }

    if (!hasNextPage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'End of Hymns',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }
}

class _HymnsLoadingState extends StatelessWidget {
  const _HymnsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: clayLoadingCenter(context),
    );
  }
}

class _HymnsStateMessage extends StatelessWidget {
  const _HymnsStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final palette = _hymnsPalette(context);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.readerBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: palette.cardShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: palette.accent, size: 34),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (message.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.mutedText,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                ),
              ],
              if (actionLabel != null && onActionPressed != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onActionPressed,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _languageLabel(String languageCode) {
  final normalized = languageCode.trim().toLowerCase();
  final language = bibleLanguageByCode[normalized];
  return language?.englishLabel ?? normalized.toUpperCase();
}

class _HymnsPalette {
  const _HymnsPalette({
    required this.headerGradient,
    required this.surface,
    required this.readerBackground,
    required this.selectedTileBackground,
    required this.iconBackground,
    required this.mutedText,
    required this.accent,
    required this.cardShadows,
    required this.tileShadows,
    required this.headerShadows,
  });

  final List<Color> headerGradient;
  final Color surface;
  final Color readerBackground;
  final Color selectedTileBackground;
  final Color iconBackground;
  final Color mutedText;
  final Color accent;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> tileShadows;
  final List<BoxShadow> headerShadows;
}

_HymnsPalette _hymnsPalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return _HymnsPalette(
      headerGradient: const <Color>[Color(0xFF2A7C62), Color(0xFF143B30)],
      surface: const Color(0xFF202B26),
      readerBackground: const Color(0xFF18211D),
      selectedTileBackground: const Color(0xFF20342C),
      iconBackground: const Color(0xFF263A32),
      mutedText: const Color(0xFFAAB7B0),
      accent: const Color(0xFF8FD8B5),
      cardShadows: <BoxShadow>[
        BoxShadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 22, offset: const Offset(0, 9)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 44, spreadRadius: -6, offset: const Offset(0, 20)),
        const BoxShadow(color: Color(0x0EFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
      ],
      tileShadows: <BoxShadow>[
        BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 5)),
        const BoxShadow(color: Color(0x08FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -2)),
      ],
      headerShadows: <BoxShadow>[
        BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 32, offset: const Offset(0, 16)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 60, spreadRadius: -8, offset: const Offset(0, 28)),
        const BoxShadow(color: Color(0x10FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-3, -4)),
      ],
    );
  }

  return _HymnsPalette(
    headerGradient: const <Color>[Color(0xFF1A5A47), Color(0xFF0F3F32)],
    surface: const Color(0xFFFBF6ED),
    readerBackground: const Color(0xFFFFFCF7),
    selectedTileBackground: const Color(0xFFE7F1EB),
    iconBackground: const Color(0xFFE3F0E9),
    mutedText: const Color(0xFF6C6A65),
    accent: const Color(0xFF195241),
    cardShadows: <BoxShadow>[
      BoxShadow(color: const Color(0xFF1A5A47).withValues(alpha: 0.22), blurRadius: 22, offset: const Offset(0, 9)),
      BoxShadow(color: const Color(0xFF1A5A47).withValues(alpha: 0.10), blurRadius: 44, spreadRadius: -6, offset: const Offset(0, 20)),
      BoxShadow(color: Colors.white.withValues(alpha: 0.90), blurRadius: 0, spreadRadius: 2, offset: const Offset(-3, -3)),
    ],
    tileShadows: <BoxShadow>[
      BoxShadow(color: const Color(0xFF1A5A47).withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 5)),
      BoxShadow(color: Colors.white.withValues(alpha: 0.92), blurRadius: 0, spreadRadius: 1, offset: const Offset(-2, -2)),
    ],
    headerShadows: <BoxShadow>[
      BoxShadow(color: const Color(0xFF0F3F32).withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 16)),
      BoxShadow(color: const Color(0xFF0F3F32).withValues(alpha: 0.16), blurRadius: 60, spreadRadius: -8, offset: const Offset(0, 28)),
      BoxShadow(color: Colors.white.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 1, offset: const Offset(-3, -4)),
    ],
  );
}
