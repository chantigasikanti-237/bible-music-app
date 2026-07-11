import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../theme/clay_decorations.dart';
import '../../controllers/app_audio_player_controller.dart';
import '../../controllers/web_youtube_player_controller.dart';
import '../../models/audio_track.dart';
import '../../services/audio_coordinator.dart';
import '../../services/bible_service.dart';
import '../../services/offline_music_service.dart';
import '../../services/user_service.dart';
import '../../widgets/adaptive_layout.dart';

// ---------------------------------------------------------------------------
// Language mapping — code (stored in UserService) ↔ display name / API name
// ---------------------------------------------------------------------------

/// All music-supported language codes in display order.
const List<String> _kMusicLangCodes = <String>[
  'te', 'hi', 'ta', 'ml', 'kn', 'mr', 'as', 'br',
  'en', 'kok', 'mni', 'or', 'pa', 'bn', 'ne', 'doi', 'ks', 'gu', 'sd',
];

/// Maps a language code to the English full name sent to the YouTube search API.
const Map<String, String> _kCodeToApiName = <String, String>{
  'te': 'Telugu',
  'hi': 'Hindi',
  'ta': 'Tamil',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'mr': 'Marathi',
  'as': 'Assamese',
  'br': 'Bodo',
  'en': 'English',
  'kok': 'Konkani',
  'mni': 'Manipuri',
  'or': 'Odia',
  'pa': 'Punjabi',
  'bn': 'Bengali',
  'ne': 'Nepali',
  'doi': 'Dogri',
  'ks': 'Kashmiri',
  'gu': 'Gujarati',
  'sd': 'Sindhi',
};

/// Display labels shown on the language selector chips.
const Map<String, String> _kCodeToDisplayName = <String, String>{
  'te': 'Telugu',
  'hi': 'Hindi',
  'ta': 'Tamil',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'mr': 'Marathi',
  'as': 'Assamese',
  'br': 'Bodo',
  'en': 'English',
  'kok': 'Konkani',
  'mni': 'Manipuri',
  'or': 'Odia',
  'pa': 'Punjabi',
  'bn': 'Bengali',
  'ne': 'Nepali',
  'doi': 'Dogri',
  'ks': 'Kashmiri',
  'gu': 'Gujarati',
  'sd': 'Sindhi',
};

/// Static curated album / theme data for Section 3.
const List<_AlbumCard> _kCuratedAlbums = <_AlbumCard>[
  _AlbumCard(
    title: 'Morning Worship',
    subtitle: 'Start your day with praise',
    icon: Icons.wb_sunny_rounded,
    gradient: <Color>[Color(0xFFF9A825), Color(0xFFFF8F00)],
  ),
  _AlbumCard(
    title: 'Praise & Adoration',
    subtitle: 'High-energy worship anthems',
    icon: Icons.favorite_rounded,
    gradient: <Color>[Color(0xFF8E24AA), Color(0xFF5E35B1)],
  ),
  _AlbumCard(
    title: 'Evening Devotion',
    subtitle: 'Quiet, reflective worship',
    icon: Icons.nightlight_round,
    gradient: <Color>[Color(0xFF1565C0), Color(0xFF0D47A1)],
  ),
  _AlbumCard(
    title: 'Festival Songs',
    subtitle: 'Joyful celebration music',
    icon: Icons.celebration_rounded,
    gradient: <Color>[Color(0xFF2E7D32), Color(0xFF1B5E20)],
  ),
];

// ---------------------------------------------------------------------------
// Page widget
// ---------------------------------------------------------------------------

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final BibleService _bibleService = BibleService();
  final OfflineMusicService _offlineSvc = OfflineMusicService();
  final TextEditingController _searchController = TextEditingController();

  late String _selectedCode;
  List<AudioTrack> _trendingTracks = <AudioTrack>[];
  bool _isLoading = false;
  String? _errorMessage;

  // Downloaded song IDs (mobile only)
  Set<String> _downloadedIds = <String>{};

  // Search state
  List<AudioTrack> _searchResults = <AudioTrack>[];
  bool _isSearching = false;
  bool _searchLoading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCode = _resolveInitialCode();
    _loadTrending();
    _refreshDownloadedIds();
  }

  Future<void> _refreshDownloadedIds() async {
    if (kIsWeb) return;
    final favIds = context.read<UserService>().user.favoriteSongs;
    final Set<String> found = <String>{};
    for (final id in favIds) {
      final path = await _offlineSvc.getSongFilePath(id);
      if (path != null) found.add(id);
    }
    if (mounted) setState(() => _downloadedIds = found);
  }

  void _onDownloadComplete(String trackId) {
    if (mounted) setState(() => _downloadedIds = {..._downloadedIds, trackId});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveInitialCode() {
    final userCode =
        context.read<UserService>().user.songsLanguage.trim().toLowerCase();
    return _kMusicLangCodes.contains(userCode) ? userCode : 'te';
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final apiName = _kCodeToApiName[_selectedCode] ?? 'Telugu';
      final tracks = await _bibleService.fetchSongsByLanguage(apiName);
      if (mounted) {
        setState(() {
          _trendingTracks = tracks;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        final msg = err.toString();
        setState(() {
          _errorMessage = msg.contains('temporarily unavailable')
              ? 'Worship songs are temporarily unavailable.\nThe YouTube content limit resets daily — please try again tomorrow.'
              : 'Could not load worship music. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _selectLanguage(String code) {
    if (code == _selectedCode) return;
    setState(() {
      _selectedCode = code;
      _trendingTracks = <AudioTrack>[];
    });
    _loadTrending();
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _clearSearch();
      return;
    }
    if (q == _lastQuery) return;
    setState(() {
      _isSearching = true;
      _searchLoading = true;
      _lastQuery = q;
      _searchResults = <AudioTrack>[];
    });
    final results = await _bibleService.searchSongs(q);
    if (mounted && _lastQuery == q) {
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchLoading = false;
      _searchResults = <AudioTrack>[];
      _lastQuery = '';
    });
  }

  Future<void> _onTrackTap(AudioTrack track, List<AudioTrack> tray) async {
    final index = tray.indexWhere((t) => t.id == track.id);
    final controller = kIsWeb
        ? (WebYouTubePlayerController.instance as AudioMiniPlayerController)
        : AppAudioPlayerController.instance;

    if (controller is AppAudioPlayerController) {
      controller.setQueue(tray, startIndex: index < 0 ? 0 : index);
    }

    await AudioCoordinator.instance.claimSong();

    if (kIsWeb) {
      await WebYouTubePlayerController.instance.toggleTrack(track);
    } else {
      await AppAudioPlayerController.instance.toggleTrack(track);
    }
  }

  void _onFavoriteTap(AudioTrack track, UserService userService) {
    if (userService.user.favoriteSongs.contains(track.id)) {
      userService.removeFavoriteSong(track.id);
    } else {
      userService.addFavoriteSong(track.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _MusicPalette.of(context);

    return AdaptiveScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        return Consumer<UserService>(
          builder: (context, userService, _) {
            final favIds = userService.user.favoriteSongs.toSet();
            final favTracks = _trendingTracks
                .where((t) => favIds.contains(t.id))
                .toList(growable: false);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                // ── Header ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.horizontalPadding,
                      layout.verticalPadding + 8,
                      layout.horizontalPadding,
                      0,
                    ),
                    child: _PageHeader(selectedCode: _selectedCode),
                  ),
                ),

                // ── Search bar ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.horizontalPadding,
                      14,
                      layout.horizontalPadding,
                      0,
                    ),
                    child: _SearchBar(
                      controller: _searchController,
                      palette: palette,
                      onSubmitted: _runSearch,
                      onChanged: (v) { if (v.trim().isEmpty) _clearSearch(); },
                      onClear: _clearSearch,
                    ),
                  ),
                ),

                // ── Search results (replaces trending + lang selector) ──
                if (_isSearching) ...<Widget>[
                  SliverToBoxAdapter(
                    child: _TraySection(
                      title: 'Search Results',
                      icon: Icons.search_rounded,
                      tracks: _searchResults,
                      favIds: favIds,
                      isLoading: _searchLoading,
                      emptyMessage: _searchLoading
                          ? 'Searching…'
                          : 'No results found. Try a different song name.',
                      horizontalPadding: layout.horizontalPadding,
                      palette: palette,
                      onTrackTap: (t) => _onTrackTap(t, _searchResults),
                      onFavoriteTap: (t) => _onFavoriteTap(t, userService),
                    ),
                  ),
                ] else ...<Widget>[
                  // ── Language selector ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 4),
                      child: _LanguageSelector(
                        selectedCode: _selectedCode,
                        onSelected: _selectLanguage,
                        palette: palette,
                      ),
                    ),
                  ),

                  // ── Section 1: Favorites ────────────────────────────
                  SliverToBoxAdapter(
                    child: _TraySection(
                      title: 'Favorites',
                      icon: Icons.favorite_rounded,
                      tracks: favTracks,
                      favIds: favIds,
                      downloadedIds: _downloadedIds,
                      isLoading: false,
                      emptyMessage: 'Tap the heart on any track to add it here.',
                      horizontalPadding: layout.horizontalPadding,
                      palette: palette,
                      onTrackTap: (t) => _onTrackTap(t, favTracks),
                      onFavoriteTap: (t) => _onFavoriteTap(t, userService),
                      onDownloadComplete: _onDownloadComplete,
                    ),
                  ),

                  // ── Section 2: Downloads ─────────────────────────────
                  if (!kIsWeb) SliverToBoxAdapter(
                    child: _TraySection(
                      title: 'Downloads',
                      icon: Icons.download_done_rounded,
                      tracks: favTracks
                          .where((t) => _downloadedIds.contains(t.id))
                          .toList(growable: false),
                      favIds: favIds,
                      downloadedIds: _downloadedIds,
                      isLoading: false,
                      emptyMessage: 'Heart a song, then tap ⬇ to save it for offline listening.',
                      horizontalPadding: layout.horizontalPadding,
                      palette: palette,
                      onTrackTap: (t) => _onTrackTap(t, favTracks),
                      onFavoriteTap: (t) => _onFavoriteTap(t, userService),
                      onDownloadComplete: null,
                    ),
                  ),

                  // ── Section 2: Trending Worship ──────────────────────
                  if (_errorMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          layout.horizontalPadding, 24,
                          layout.horizontalPadding, 4,
                        ),
                        child: _ErrorState(
                          message: _errorMessage!,
                          onRetry: _loadTrending,
                          palette: palette,
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: _TraySection(
                        title: 'Trending Worship in '
                            '${_kCodeToDisplayName[_selectedCode] ?? _selectedCode}',
                        icon: Icons.trending_up_rounded,
                        tracks: _trendingTracks,
                        favIds: favIds,
                        isLoading: _isLoading,
                        emptyMessage: 'No tracks found for this language.',
                        horizontalPadding: layout.horizontalPadding,
                        palette: palette,
                        onTrackTap: (t) => _onTrackTap(t, _trendingTracks),
                        onFavoriteTap: (t) => _onFavoriteTap(t, userService),
                      ),
                    ),

                  // ── Section 3: Devotional Albums & Playlists ─────────
                  SliverToBoxAdapter(
                    child: _AlbumsSection(
                      horizontalPadding: layout.horizontalPadding,
                      palette: palette,
                    ),
                  ),
                ],

                // ── Bottom padding for mini player ───────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(height: layout.useSideNavigation ? 100 : 80),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Page header
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.selectedCode});

  final String selectedCode;

  @override
  Widget build(BuildContext context) {
    final palette = _MusicPalette.of(context);
    final langName = _kCodeToDisplayName[selectedCode] ?? selectedCode;

    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette.headerGradient,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.queue_music_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Worship Music',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
              ),
              Text(
                langName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.palette,
    required this.onSubmitted,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final _MusicPalette palette;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search any song…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : const SizedBox.shrink(),
        ),
        filled: true,
        fillColor: palette.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language selector — horizontal chip row
// ---------------------------------------------------------------------------

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.selectedCode,
    required this.onSelected,
    required this.palette,
  });

  final String selectedCode;
  final ValueChanged<String> onSelected;
  final _MusicPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kMusicLangCodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final code = _kMusicLangCodes[index];
          final label = _kCodeToDisplayName[code] ?? code;
          final selected = code == selectedCode;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(code),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? palette.selectedChipBg : palette.chip,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected ? palette.chipSelectedShadows : palette.chipShadows,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color:
                            selected ? palette.accent : palette.mutedText,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal tray section
// ---------------------------------------------------------------------------

class _TraySection extends StatelessWidget {
  const _TraySection({
    required this.title,
    required this.icon,
    required this.tracks,
    required this.favIds,
    required this.isLoading,
    required this.emptyMessage,
    required this.horizontalPadding,
    required this.palette,
    required this.onTrackTap,
    required this.onFavoriteTap,
    this.downloadedIds = const <String>{},
    this.onDownloadComplete,
  });

  final String title;
  final IconData icon;
  final List<AudioTrack> tracks;
  final Set<String> favIds;
  final Set<String> downloadedIds;
  final bool isLoading;
  final String emptyMessage;
  final double horizontalPadding;
  final _MusicPalette palette;
  final ValueChanged<AudioTrack> onTrackTap;
  final ValueChanged<AudioTrack> onFavoriteTap;
  final ValueChanged<String>? onDownloadComplete;

  static const double _cardHeight = 200;
  static const double _trayHeight = _cardHeight + 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Section heading
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          SizedBox(
            height: _trayHeight,
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => _TrackCardSkeleton(palette: palette),
      );
    }

    if (tracks.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: _EmptyTray(message: emptyMessage, palette: palette),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (BuildContext context, int index) {
        final track = tracks[index];
        return _TrackCard(
          track: track,
          isFavorited: favIds.contains(track.id),
          isDownloaded: downloadedIds.contains(track.id),
          palette: palette,
          onTap: () => onTrackTap(track),
          onFavoriteTap: () => onFavoriteTap(track),
          onDownloadComplete: onDownloadComplete != null
              ? () => onDownloadComplete!(track.id)
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual horizontal track card
// ---------------------------------------------------------------------------

class _TrackCard extends StatefulWidget {
  const _TrackCard({
    required this.track,
    required this.isFavorited,
    required this.isDownloaded,
    required this.palette,
    required this.onTap,
    required this.onFavoriteTap,
    this.onDownloadComplete,
  });

  static const double _width = 154;
  static const double _height = 200;
  static const double _thumbHeight = 100;

  final AudioTrack track;
  final bool isFavorited;
  final bool isDownloaded;
  final _MusicPalette palette;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback? onDownloadComplete;

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  bool _isDownloading = false;

  static const Duration _downloadTimeout = Duration(minutes: 3);

  Future<void> _download() async {
    if (_isDownloading || widget.isDownloaded) return;
    setState(() => _isDownloading = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    showClaySnackBar(context, 'Downloading for offline… may take a minute');

    try {
      final url = '${ApiConfig.baseUrl}/api/audio/stream/${widget.track.id}';
      await OfflineMusicService()
          .saveSongAudio(songId: widget.track.id, audioUrl: url)
          .timeout(_downloadTimeout);

      if (mounted) {
        setState(() => _isDownloading = false);
        widget.onDownloadComplete?.call();
        messenger.clearSnackBars();
        showClaySnackBar(context, 'Saved for offline listening', type: ClaySnackType.success);
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _isDownloading = false);
        messenger.clearSnackBars();
        showClaySnackBar(context, 'Download timed out. Try again.', type: ClaySnackType.error);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
        messenger.clearSnackBars();
        showClaySnackBar(context, 'Download failed. Try again.', type: ClaySnackType.error);
      }
    }
  }

  Widget _buildDownloadBtn() {
    final p = widget.palette;
    if (_isDownloading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(p.accent),
        ),
      );
    }
    if (widget.isDownloaded) {
      return Icon(Icons.download_done_rounded, size: 20, color: p.accent);
    }
    return GestureDetector(
      onTap: _download,
      child: Icon(Icons.download_rounded, size: 20, color: p.mutedText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return SizedBox(
      width: _TrackCard._width,
      height: _TrackCard._height,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: palette.cardShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: _TrackCard._width,
                    height: _TrackCard._thumbHeight,
                    child: _CardThumbnail(
                      url: widget.track.thumbnailUrl,
                      palette: palette,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            widget.track.title.isEmpty
                                ? 'Untitled track'
                                : widget.track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                          ),
                        ),
                        Text(
                          widget.track.channelTitle.isEmpty
                              ? 'Unknown'
                              : widget.track.channelTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: palette.mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: palette.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            // Download button: mobile + favorited + download allowed
                            if (!kIsWeb &&
                                widget.isFavorited &&
                                widget.onDownloadComplete != null)
                              _buildDownloadBtn(),
                            // Downloaded badge: mobile + downloaded + no download button
                            if (!kIsWeb &&
                                widget.isDownloaded &&
                                widget.onDownloadComplete == null)
                              Icon(Icons.download_done_rounded,
                                  size: 20, color: palette.accent),
                            GestureDetector(
                              onTap: widget.onFavoriteTap,
                              child: Icon(
                                widget.isFavorited
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 18,
                                color: widget.isFavorited
                                    ? palette.accent
                                    : palette.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardThumbnail extends StatelessWidget {
  const _CardThumbnail({required this.url, required this.palette});

  final String url;
  final _MusicPalette palette;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return _ThumbnailFallback(palette: palette);
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _ThumbnailFallback(palette: palette),
      loadingBuilder: (_, Widget child, ImageChunkEvent? progress) {
        if (progress == null) return child;
        return _ThumbnailFallback(palette: palette);
      },
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.palette});

  final _MusicPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.thumbnailFallback,
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton card for loading state
// ---------------------------------------------------------------------------

class _TrackCardSkeleton extends StatefulWidget {
  const _TrackCardSkeleton({required this.palette});

  final _MusicPalette palette;

  @override
  State<_TrackCardSkeleton> createState() => _TrackCardSkeletonState();
}

class _TrackCardSkeletonState extends State<_TrackCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 0.90)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 154,
        height: 200,
        decoration: BoxDecoration(
          color: widget.palette.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: widget.palette.cardShadows,
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 154,
              height: 100,
              decoration: BoxDecoration(
                color: widget.palette.skeleton,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    height: 11,
                    decoration: BoxDecoration(
                      color: widget.palette.skeleton,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: 90,
                    height: 9,
                    decoration: BoxDecoration(
                      color: widget.palette.skeleton,
                      borderRadius: BorderRadius.circular(5),
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

// ---------------------------------------------------------------------------
// Empty tray placeholder
// ---------------------------------------------------------------------------

class _EmptyTray extends StatelessWidget {
  const _EmptyTray({required this.message, required this.palette});

  final String message;
  final _MusicPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: palette.cardShadows,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.music_off_rounded, color: palette.mutedText, size: 28),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 3: Devotional Albums & Playlists
// ---------------------------------------------------------------------------

class _AlbumCard {
  const _AlbumCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}

class _AlbumsSection extends StatelessWidget {
  const _AlbumsSection({
    required this.horizontalPadding,
    required this.palette,
  });

  final double horizontalPadding;
  final _MusicPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
            child: Row(
              children: <Widget>[
                Icon(Icons.album_rounded, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Text(
                  'Devotional Albums & Playlists',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: _kCuratedAlbums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                return _CuratedAlbumCard(album: _kCuratedAlbums[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CuratedAlbumCard extends StatelessWidget {
  const _CuratedAlbumCard({required this.album});

  final _AlbumCard album;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          showClaySnackBar(context, '${album.title} coming soon');
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 160,
          height: 122,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: album.gradient,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: album.gradient.last.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: album.gradient.last.withValues(alpha: 0.20),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.15),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(-2, -3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(album.icon, color: Colors.white.withValues(alpha: 0.9), size: 28),
                const Spacer(),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  album.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.palette,
  });

  final String message;
  final VoidCallback onRetry;
  final _MusicPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: palette.cardShadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.errorBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.wifi_off_rounded, color: palette.error, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            'Worship music unavailable',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.mutedText,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Colour palette
// ---------------------------------------------------------------------------

class _MusicPalette {
  const _MusicPalette({
    required this.card,
    required this.chip,
    required this.selectedChipBg,
    required this.accent,
    required this.mutedText,
    required this.thumbnailFallback,
    required this.skeleton,
    required this.headerGradient,
    required this.error,
    required this.errorBg,
    required this.cardShadows,
    required this.chipShadows,
    required this.chipSelectedShadows,
  });

  final Color card;
  final Color chip;
  final Color selectedChipBg;
  final Color accent;
  final Color mutedText;
  final Color thumbnailFallback;
  final Color skeleton;
  final List<Color> headerGradient;
  final Color error;
  final Color errorBg;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> chipShadows;
  final List<BoxShadow> chipSelectedShadows;

  static _MusicPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return _MusicPalette(
        card: const Color(0xFF1C2621),
        chip: const Color(0xFF1B2420),
        selectedChipBg: const Color(0xFF21362E),
        accent: const Color(0xFF8FD8B5),
        mutedText: const Color(0xFFA7B4AD),
        thumbnailFallback: const Color(0xFF2D6A58),
        skeleton: const Color(0xFF2A3631),
        headerGradient: const <Color>[Color(0xFF2A7C62), Color(0xFF143B30)],
        error: const Color(0xFFFFB4AB),
        errorBg: const Color(0xFF3A1C1A),
        cardShadows: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 22, offset: const Offset(0, 9)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 44, spreadRadius: -6, offset: const Offset(0, 20)),
          const BoxShadow(color: Color(0x0EFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
        ],
        chipShadows: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3)),
          const BoxShadow(color: Color(0x06FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -1)),
        ],
        chipSelectedShadows: <BoxShadow>[
          BoxShadow(color: const Color(0xFF8FD8B5).withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4)),
          const BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -1)),
        ],
      );
    }

    return _MusicPalette(
      card: const Color(0xFFFFFEFC),
      chip: const Color(0xFFF4EDE2),
      selectedChipBg: const Color(0xFFE4F1EA),
      accent: const Color(0xFF185642),
      mutedText: const Color(0xFF6C6A65),
      thumbnailFallback: const Color(0xFF28745E),
      skeleton: const Color(0xFFE9DFD1),
      headerGradient: const <Color>[Color(0xFF1A5A47), Color(0xFF0F3F32)],
      error: const Color(0xFFBA1A1A),
      errorBg: const Color(0xFFFCE8E8),
      cardShadows: <BoxShadow>[
        BoxShadow(color: const Color(0xFF1A5A47).withValues(alpha: 0.22), blurRadius: 22, offset: const Offset(0, 9)),
        BoxShadow(color: const Color(0xFF1A5A47).withValues(alpha: 0.10), blurRadius: 44, spreadRadius: -6, offset: const Offset(0, 20)),
        BoxShadow(color: Colors.white.withValues(alpha: 0.90), blurRadius: 0, spreadRadius: 2, offset: const Offset(-3, -3)),
      ],
      chipShadows: <BoxShadow>[
        BoxShadow(color: const Color(0xFF7D6A45).withValues(alpha: 0.16), blurRadius: 8, offset: const Offset(0, 3)),
        BoxShadow(color: Colors.white.withValues(alpha: 0.90), blurRadius: 0, spreadRadius: 1, offset: const Offset(-1, -1)),
      ],
      chipSelectedShadows: <BoxShadow>[
        BoxShadow(color: const Color(0xFF185642).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        BoxShadow(color: Colors.white.withValues(alpha: 0.88), blurRadius: 0, spreadRadius: 1, offset: const Offset(-1, -1)),
      ],
    );
  }
}
