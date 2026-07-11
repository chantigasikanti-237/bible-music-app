import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/audio_track.dart';
import '../services/bible_service.dart';
import '../services/offline_music_service.dart';

void _emptyTrackSelected(AudioTrack track) {}

class AudioTrackListView extends StatefulWidget {
  const AudioTrackListView({
    super.key,
    this.bibleService,
    this.initialLanguage = 'Telugu',
    this.onTrackSelected = _emptyTrackSelected,
    this.favoriteSongIds = const <String>{},
    this.onFavoriteTap,
  });

  static const List<String> supportedLanguages = <String>[
    'Telugu',
    'Hindi',
    'Tamil',
    'Malayalam',
    'Kannada',
  ];

  final BibleService? bibleService;
  final String initialLanguage;
  final ValueChanged<AudioTrack> onTrackSelected;
  final Set<String> favoriteSongIds;
  final ValueChanged<AudioTrack>? onFavoriteTap;

  @override
  State<AudioTrackListView> createState() => _AudioTrackListViewState();
}

class _AudioTrackListViewState extends State<AudioTrackListView> {
  late final BibleService _bibleService;
  late String _selectedLanguage;
  late Future<List<AudioTrack>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _bibleService = widget.bibleService ?? BibleService();
    _selectedLanguage = _resolveInitialLanguage(widget.initialLanguage);
    _tracksFuture = _bibleService.fetchSongsByLanguage(_selectedLanguage);
  }

  String _resolveInitialLanguage(String language) {
    final normalized = language.trim().toLowerCase();
    return AudioTrackListView.supportedLanguages.firstWhere(
      (String option) => option.toLowerCase() == normalized,
      orElse: () => 'Telugu',
    );
  }

  void _selectLanguage(String language) {
    if (language == _selectedLanguage) {
      return;
    }

    setState(() {
      _selectedLanguage = language;
      _tracksFuture = _bibleService.fetchSongsByLanguage(language);
    });
  }

  void onTrackSelected(AudioTrack track) {
    widget.onTrackSelected(track);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioTrackPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: palette.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LanguageSelector(
            selectedLanguage: _selectedLanguage,
            onSelected: _selectLanguage,
          ),
          Expanded(
            child: FutureBuilder<List<AudioTrack>>(
              future: _tracksFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<List<AudioTrack>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _AudioTrackLoadingList();
                }

                final tracks = snapshot.data ?? const <AudioTrack>[];
                if (tracks.isEmpty) {
                  return _AudioTracksEmptyState(language: _selectedLanguage);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  itemCount: tracks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final track = tracks[index];
                    final onFav = widget.onFavoriteTap;
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                      child: _AudioTrackTile(
                        track: track,
                        onTap: () => onTrackSelected(track),
                        isFavorited:
                            widget.favoriteSongIds.contains(track.id),
                        onFavoriteTap:
                            onFav != null ? () => onFav(track) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.selectedLanguage,
    required this.onSelected,
  });

  final String selectedLanguage;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        itemCount: AudioTrackListView.supportedLanguages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final language = AudioTrackListView.supportedLanguages[index];
          return _LanguageChip(
            label: language,
            selected: language == selectedLanguage,
            onTap: () => onSelected(language),
          );
        },
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioTrackPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: palette.accent.withValues(alpha: 0.08),
        highlightColor: palette.accent.withValues(alpha: 0.04),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? palette.selectedChipBackground : palette.chip,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? palette.chipSelectedShadows : palette.chipShadows,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? palette.accent : palette.mutedText,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioTrackTile extends StatefulWidget {
  const _AudioTrackTile({
    required this.track,
    required this.onTap,
    this.isFavorited = false,
    this.onFavoriteTap,
  });

  final AudioTrack track;
  final VoidCallback onTap;
  final bool isFavorited;
  final VoidCallback? onFavoriteTap;

  @override
  State<_AudioTrackTile> createState() => _AudioTrackTileState();
}

class _AudioTrackTileState extends State<_AudioTrackTile> {
  late final OfflineMusicService _offlineMusicService;
  late Future<bool> _isOfflineAvailableFuture;

  @override
  void initState() {
    super.initState();
    _offlineMusicService = OfflineMusicService();
    _isOfflineAvailableFuture = _checkOfflineAvailability();
  }

  Future<bool> _checkOfflineAvailability() async {
    if (kIsWeb || !widget.isFavorited) return false;
    final path = await _offlineMusicService.getSongFilePath(widget.track.id);
    return path != null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioTrackPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: palette.accent.withValues(alpha: 0.07),
        highlightColor: palette.accent.withValues(alpha: 0.035),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          decoration: BoxDecoration(
            color: palette.tile,
            borderRadius: BorderRadius.circular(18),
            boxShadow: palette.tileShadows,
          ),
          child: Row(
            children: <Widget>[
              _TrackThumbnail(url: widget.track.thumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      widget.track.title.isEmpty ? 'Untitled track' : widget.track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.track.channelTitle.isEmpty
                          ? 'Unknown channel'
                          : widget.track.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                    ),
                  ],
                ),
              ),
              if (widget.isFavorited && !kIsWeb)
                FutureBuilder<bool>(
                  future: _isOfflineAvailableFuture,
                  builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                    final isOffline = snapshot.data ?? false;
                    if (!isOffline) {
                      return const SizedBox.shrink();
                    }
                    return Tooltip(
                      message: 'Available offline',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.download_done_rounded,
                          size: 18,
                          color: palette.accent,
                        ),
                      ),
                    );
                  },
                ),
              if (widget.onFavoriteTap != null)
                IconButton(
                  tooltip: widget.isFavorited ? 'Remove from favorites' : 'Add to favorites',
                  icon: Icon(
                    widget.isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: widget.isFavorited ? palette.accent : palette.mutedText,
                  ),
                  onPressed: widget.onFavoriteTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackThumbnail extends StatelessWidget {
  const _TrackThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioTrackPalette.of(context);

    return SizedBox(
      width: 92,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url.trim().isEmpty
              ? _ThumbnailFallback(color: palette.thumbnailFallback)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) =>
                      _ThumbnailFallback(color: palette.thumbnailFallback),
                  loadingBuilder: (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return _ThumbnailFallback(
                      color: palette.thumbnailFallback,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AudioTrackLoadingList extends StatelessWidget {
  const _AudioTrackLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        return const _AudioTrackSkeletonTile();
      },
    );
  }
}

class _AudioTrackSkeletonTile extends StatefulWidget {
  const _AudioTrackSkeletonTile();

  @override
  State<_AudioTrackSkeletonTile> createState() =>
      _AudioTrackSkeletonTileState();
}

class _AudioTrackSkeletonTileState extends State<_AudioTrackSkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.52, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioTrackPalette.of(context);

    return FadeTransition(
      opacity: _opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: BorderRadius.circular(18),
          boxShadow: palette.tileShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              _SkeletonBlock(
                width: 92,
                height: 52,
                radius: 12,
                color: palette.skeleton,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SkeletonBlock(
                      width: double.infinity,
                      height: 13,
                      radius: 6,
                      color: palette.skeleton,
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      child: _SkeletonBlock(
                        width: double.infinity,
                        height: 13,
                        radius: 6,
                        color: palette.skeleton,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FractionallySizedBox(
                      widthFactor: 0.42,
                      child: _SkeletonBlock(
                        width: double.infinity,
                        height: 10,
                        radius: 5,
                        color: palette.skeleton,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _AudioTracksEmptyState extends StatelessWidget {
  const _AudioTracksEmptyState({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioTrackPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.selectedChipBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: palette.accent,
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No tracks found in this language',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              language,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioTrackPalette {
  const _AudioTrackPalette({
    required this.surface,
    required this.tile,
    required this.chip,
    required this.selectedChipBackground,
    required this.selectedChipBorder,
    required this.border,
    required this.accent,
    required this.mutedText,
    required this.thumbnailFallback,
    required this.skeleton,
    required this.cardShadows,
    required this.tileShadows,
    required this.chipShadows,
    required this.chipSelectedShadows,
  });

  final Color surface;
  final Color tile;
  final Color chip;
  final Color selectedChipBackground;
  final Color selectedChipBorder;
  final Color border;
  final Color accent;
  final Color mutedText;
  final Color thumbnailFallback;
  final Color skeleton;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> tileShadows;
  final List<BoxShadow> chipShadows;
  final List<BoxShadow> chipSelectedShadows;

  static _AudioTrackPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _AudioTrackPalette(
        surface: Color(0xFF151D19),
        tile: Color(0xFF1C2621),
        chip: Color(0xFF1B2420),
        selectedChipBackground: Color(0xFF21362E),
        selectedChipBorder: Color(0xFF426958),
        border: Color(0xFF2E3D36),
        accent: Color(0xFF8FD8B5),
        mutedText: Color(0xFFA7B4AD),
        thumbnailFallback: Color(0xFF2D6A58),
        skeleton: Color(0xFF2A3631),
        cardShadows: <BoxShadow>[
          BoxShadow(color: Color(0x6B000000), blurRadius: 22, offset: Offset(0, 9)),
          BoxShadow(color: Color(0x2E000000), blurRadius: 44, spreadRadius: -6, offset: Offset(0, 20)),
          BoxShadow(color: Color(0x0EFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
        ],
        tileShadows: <BoxShadow>[
          BoxShadow(color: Color(0x52000000), blurRadius: 12, offset: Offset(0, 5)),
          BoxShadow(color: Color(0x08FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -2)),
        ],
        chipShadows: <BoxShadow>[
          BoxShadow(color: Color(0x42000000), blurRadius: 8, offset: Offset(0, 3)),
          BoxShadow(color: Color(0x08FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -1)),
        ],
        chipSelectedShadows: <BoxShadow>[
          BoxShadow(color: Color(0x52000000), blurRadius: 10, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x0EFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -1)),
        ],
      );
    }

    return const _AudioTrackPalette(
      surface: Color(0xFFFFFCF7),
      tile: Color(0xFFFFFEFC),
      chip: Color(0xFFF4EDE2),
      selectedChipBackground: Color(0xFFE4F1EA),
      selectedChipBorder: Color(0xFFB9D6C8),
      border: Color(0xFFE6DAC8),
      accent: Color(0xFF185642),
      mutedText: Color(0xFF6C6A65),
      thumbnailFallback: Color(0xFF28745E),
      skeleton: Color(0xFFE9DFD1),
      cardShadows: <BoxShadow>[
        BoxShadow(color: Color(0x381A5A47), blurRadius: 22, offset: Offset(0, 9)),
        BoxShadow(color: Color(0x1A1A5A47), blurRadius: 44, spreadRadius: -6, offset: Offset(0, 20)),
        BoxShadow(color: Color(0xE6FFFFFF), blurRadius: 0, spreadRadius: 2, offset: Offset(-3, -3)),
      ],
      tileShadows: <BoxShadow>[
        BoxShadow(color: Color(0x2E1A5A47), blurRadius: 12, offset: Offset(0, 5)),
        BoxShadow(color: Color(0xEBFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
      ],
      chipShadows: <BoxShadow>[
        BoxShadow(color: Color(0x1C1A5A47), blurRadius: 8, offset: Offset(0, 3)),
        BoxShadow(color: Color(0xEBFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -1)),
      ],
      chipSelectedShadows: <BoxShadow>[
        BoxShadow(color: Color(0x2E1A5A47), blurRadius: 10, offset: Offset(0, 4)),
        BoxShadow(color: Color(0xE6FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -1)),
      ],
    );
  }
}
