import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/bible_languages.dart';
import '../../theme/clay_decorations.dart';
import '../../controllers/app_shell_controller.dart';
import '../../controllers/bible_controller.dart';
import '../../models/bible_audio_profile.dart';
import '../../models/bible_book.dart';
import '../../models/bible_catalog.dart';
import '../../models/chapter_response.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;

import '../../services/audio_coordinator.dart';
import '../../services/audio_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/adaptive_layout.dart';
import 'downloads_manager_page.dart';
import 'inline_verse_text.dart';

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  bool _didInitialize = false;
  late final AudioService _audioService;
  final TextEditingController _bibleSearchController = TextEditingController();
  String _bibleSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
  }

  @override
  void dispose() {
    _bibleSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }

    _didInitialize = true;
    final bibleController = context.read<BibleController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      bibleController.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BibleController, AppShellController>(
      builder: (
        BuildContext context,
        BibleController bibleController,
        AppShellController shellController,
        _,
      ) {
        _syncShellVisibility(
          shellController: shellController,
          immersiveMode: bibleController.immersiveMode,
        );
        final canPop = bibleController.viewMode == BibleViewMode.books &&
            !bibleController.immersiveMode;
        final palette = _biblePalette(context);

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              bibleController.handleBack();
            }
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: palette.pageGradient,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: bibleController.immersiveMode
                        ? const SizedBox.shrink()
                        : _BibleHeader(
                            key: ValueKey<String>(
                              '${bibleController.viewMode}:${bibleController.selectedLanguageCode}:${bibleController.currentChapterNumber}:${bibleController.currentVersion?.id ?? 0}',
                            ),
                            title: _headerTitle(bibleController),
                            sourceLabel: bibleController
                                .currentCatalog?.version.sourceLabel,
                            canGoBack:
                                bibleController.viewMode != BibleViewMode.books,
                            onBack: bibleController.handleBack,
                            onOpenSettings: _openSettingsHub,
                            playButton: bibleController.isInReader
                                ? StreamBuilder<bool>(
                                    stream: _audioService.playerStateStream,
                                    initialData: false,
                                    builder: (
                                      BuildContext context,
                                      AsyncSnapshot<bool> snapshot,
                                    ) {
                                      final isPlaying = snapshot.data ?? false;
                                      final noAudio =
                                          !bibleController
                                              .currentVersionSupportsAudio;
                                      return IconButton(
                                        tooltip: bibleController
                                                .canPlayCurrentAudio
                                            ? isPlaying
                                                ? 'Pause'
                                                : 'Play'
                                            : bibleController
                                                    .currentVersionSupportsAudio
                                                ? 'Audio disabled'
                                                : 'No audio available',
                                        onPressed: bibleController
                                                .canPlayCurrentAudio
                                            ? _toggleCurrentChapterAudio
                                            : noAudio
                                                ? () {
                                                    final lang =
                                                        bibleLanguageForCode(
                                                      bibleController
                                                          .selectedLanguageCode,
                                                    ).englishLabel;
                                                    ScaffoldMessenger.of(context).clearSnackBars();
                                                    showClaySnackBar(context, 'No audio available for $lang', type: ClaySnackType.error);
                                                  }
                                                : null,
                                        icon: Icon(
                                          isPlaying
                                              ? Icons
                                                  .pause_circle_filled_rounded
                                              : Icons.play_circle_fill_rounded,
                                        ),
                                        disabledColor: Colors.white
                                            .withValues(alpha: 0.48),
                                      );
                                    },
                                  )
                                : null,
                          ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: bibleController.catalogLoading &&
                            bibleController.books.isNotEmpty
                        ? Padding(
                            key: const ValueKey<String>(
                              'catalog-loading-indicator',
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: palette.progressTrack,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    palette.accent),
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey<String>('catalog-loading-idle'),
                          ),
                  ),
                  Expanded(
                    child: _buildBody(context, bibleController),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, BibleController bibleController) {
    if (bibleController.catalogLoading && bibleController.books.isEmpty) {
      return clayLoadingCenter(context);
    }

    if (bibleController.catalogError != null && bibleController.books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                bibleController.catalogError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: bibleController.refreshCatalog,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    switch (bibleController.viewMode) {
      case BibleViewMode.books:
        return _buildBooksLayout(bibleController);
      case BibleViewMode.chapters:
        final currentBook = bibleController.currentBook;
        if (currentBook == null) {
          return const Center(child: Text('Select a book to continue'));
        }
        return _buildChaptersLayout(
          bibleController: bibleController,
          currentBook: currentBook,
        );
      case BibleViewMode.reader:
        final currentBook = bibleController.currentBook;
        if (currentBook == null) {
          return const Center(child: Text('Select a book to continue'));
        }
        return _ReaderView(
          key: ValueKey<String>(
            '${bibleController.selectedLanguageCode}:${bibleController.currentVersion?.id ?? 0}:${currentBook.id}',
          ),
          controller: bibleController,
          onToggleImmersive: bibleController.toggleImmersiveMode,
        );
    }
  }

  Widget _buildBooksLayout(BibleController bibleController) {
    final allBooks = bibleController.books;
    final query = _bibleSearchQuery.toLowerCase();
    final filteredBooks = query.isEmpty
        ? allBooks
        : allBooks.where((b) {
            return b.title.toLowerCase().contains(query) ||
                b.fullTitle.toLowerCase().contains(query) ||
                b.abbreviation.toLowerCase().contains(query);
          }).toList();

    final searchBar = _BibleSearchBar(
      controller: _bibleSearchController,
      onChanged: (v) => setState(() => _bibleSearchQuery = v.trim()),
      onClear: () {
        _bibleSearchController.clear();
        setState(() => _bibleSearchQuery = '');
      },
    );

    final booksList = _BooksList(
      books: filteredBooks,
      languageCode: bibleController.selectedLanguageCode,
      onRefresh: bibleController.refreshCatalog,
      onSelectBook: (book) {
        _bibleSearchController.clear();
        setState(() => _bibleSearchQuery = '');
        bibleController.openBook(book);
      },
    );

    return ConstraintLayout(
      builder: (BuildContext context, AdaptiveLayoutInfo layout) {
        if (!layout.useTwoPane) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: searchBar,
              ),
              Expanded(child: booksList),
            ],
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            0,
            layout.horizontalPadding,
            24,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: layout.splitSecondaryFlex,
                child: const _BibleSplitInfoCard(
                  title: 'Choose a book',
                  description:
                      'Portrait keeps the Bible library in a single vertical list. Landscape opens a second pane so the library stays readable on wider screens.',
                  icon: Icons.menu_book_rounded,
                ),
              ),
              SizedBox(width: layout.paneSpacing),
              Expanded(
                flex: layout.splitPrimaryFlex,
                child: DecoratedBox(
                  decoration: _splitPaneDecoration(context),
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: searchBar,
                      ),
                      Expanded(child: booksList),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChaptersLayout({
    required BibleController bibleController,
    required BibleBook currentBook,
  }) {
    final chapterGrid = _ChapterGrid(
      book: currentBook,
      languageCode: bibleController.selectedLanguageCode,
      onSelectChapter: bibleController.openReader,
    );

    return ConstraintLayout(
      builder: (BuildContext context, AdaptiveLayoutInfo layout) {
        if (!layout.useTwoPane) {
          return chapterGrid;
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            8,
            layout.horizontalPadding,
            24,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: layout.splitSecondaryFlex,
                child: _BibleSplitInfoCard(
                  title: currentBook.title,
                  description:
                      '${currentBook.chapterCount} chapters available. Pick a chapter on the right to enter the reader without crowding the grid.',
                  icon: Icons.view_module_rounded,
                ),
              ),
              SizedBox(width: layout.paneSpacing),
              Expanded(
                flex: layout.splitPrimaryFlex,
                child: DecoratedBox(
                  decoration: _splitPaneDecoration(context),
                  child: chapterGrid,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _splitPaneDecoration(BuildContext context) {
    final palette = _biblePalette(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette.panelGradient,
      ),
      borderRadius: BorderRadius.circular(30),
      boxShadow: palette.cardShadows,
    );
  }

  String _headerTitle(BibleController controller) {
    switch (controller.viewMode) {
      case BibleViewMode.books:
        return 'Bible';
      case BibleViewMode.chapters:
        return controller.currentBook?.title ?? 'Bible';
      case BibleViewMode.reader:
        return '${controller.currentBook?.title ?? 'Bible'} ${controller.currentChapterNumber}';
    }
  }

  void _syncShellVisibility({
    required AppShellController shellController,
    required bool immersiveMode,
  }) {
    final shouldShowNavigationBar = !immersiveMode;
    if (shellController.showNavigationBar == shouldShowNavigationBar) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppShellController>().setNavigationBarVisible(
            shouldShowNavigationBar,
          );
    });
  }

  Future<void> _toggleCurrentChapterAudio() async {
    final bibleController = context.read<BibleController>();
    try {
      final chapter = await bibleController.loadCurrentChapter();
      final audioSource = await bibleController.resolveAudioForCurrentChapter(
        chapter.audioUrl,
      );
      if (audioSource == null || audioSource.isEmpty) {
        throw StateError('Audio is not available for this chapter.');
      }

      // Stop worship-song player if active before claiming Bible audio.
      await AudioCoordinator.instance.claimBible(audioSource);

      // Build a MediaItem tag for locally stored audio so just_audio_background
      // keeps the session alive when the app is backgrounded. Streamed audio
      // gets no tag and is stopped by AudioCoordinator on lifecycle pause.
      MediaItem? tag;
      if (AudioCoordinator.isLocalAudioSource(audioSource)) {
        final book = bibleController.currentBook;
        final chapterNum = bibleController.currentChapterNumber;
        tag = MediaItem(
          id: audioSource,
          title: book != null
              ? '${book.title} $chapterNum'
              : 'Chapter $chapterNum',
          artist: 'Bible',
          album: 'Bible App',
        );
      }

      await _audioService.togglePlayPause(audioSource, tag: tag);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    }
  }

  Future<void> _openDownloadsManager([BuildContext? navigatorContext]) async {
    final navigator = Navigator.of(navigatorContext ?? context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const DownloadsManagerPage(),
      ),
    );
  }

  Future<void> _openSettingsHub() async {
    final controller = context.read<BibleController>();
    await controller.ensureAvailableVersions();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _BibleSettingsSheet(
            onOpenDownloads: () async {
              await _openDownloadsManager(sheetContext);
            },
          ),
        );
      },
    );
  }
}

class _BibleHeader extends StatelessWidget {
  const _BibleHeader({
    super.key,
    required this.title,
    required this.sourceLabel,
    required this.canGoBack,
    required this.onBack,
    required this.onOpenSettings,
    this.playButton,
  });

  final String title;
  final String? sourceLabel;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final Widget? playButton;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth <= 380;
        final borderRadius = compact ? 26.0 : 32.0;
        final actionSize = compact ? 46.0 : 52.0;
        final horizontalGap = compact ? 8.0 : 12.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            8,
            compact ? 10 : 12,
            8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  compact ? 12 : 16,
                  compact ? 12 : 16,
                  compact ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette.panelGradient
                        .map((Color color) => color.withValues(alpha: 0.96))
                        .toList(),
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: palette.cardShadows,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (canGoBack) ...<Widget>[
                      _HeaderIconShell(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: onBack,
                        size: actionSize,
                      ),
                      SizedBox(width: horizontalGap),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  fontSize: compact ? 22 : null,
                                  height: compact ? 1.08 : null,
                                ),
                          ),
                          if (sourceLabel != null &&
                              sourceLabel!.trim().isNotEmpty) ...<Widget>[
                            SizedBox(height: compact ? 4 : 6),
                            Text(
                              sourceLabel!,
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: palette.secondaryMutedText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: compact ? 11.5 : null,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: horizontalGap),
                    if (playButton != null) ...<Widget>[
                      _HeaderActionShell(
                        size: actionSize,
                        child: playButton!,
                      ),
                      SizedBox(width: compact ? 8 : 10),
                    ],
                    _HeaderIconShell(
                      icon: Icons.public_rounded,
                      tooltip: 'Settings',
                      onTap: onOpenSettings,
                      size: actionSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BibleSettingsSheet extends StatefulWidget {
  const _BibleSettingsSheet({
    required this.onOpenDownloads,
  });

  final Future<void> Function() onOpenDownloads;

  @override
  State<_BibleSettingsSheet> createState() => _BibleSettingsSheetState();
}

class _BibleSettingsSheetState extends State<_BibleSettingsSheet> {
  bool _changingLanguage = false;
  bool _changingVersion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<BibleController>().ensureAvailableVersions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleController>(
      builder: (
        BuildContext context,
        BibleController controller,
        _,
      ) {
        final currentVersion = controller.currentVersion;
        final audioProfiles = controller.audioProfiles;
        final palette = _biblePalette(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.handle,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Bible settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose language, translation, audio, and offline options in one place.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        _SettingsSection(
                          title: 'Language',
                          child: Column(
                            children: bibleLanguageOptions.map((option) {
                              final selected = option.code ==
                                  controller.selectedLanguageCode;
                              return _SettingsOptionTile(
                                title: option.nativeLabel,
                                subtitle: option.englishLabel,
                                selected: selected,
                                trailing: selected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: palette.accent,
                                      )
                                    : null,
                                onTap: _changingLanguage
                                    ? null
                                    : () async {
                                        if (selected) {
                                          return;
                                        }
                                        setState(
                                            () => _changingLanguage = true);
                                        try {
                                          await controller.selectLanguage(
                                            option.code,
                                          );
                                          await controller
                                              .ensureAvailableVersions();
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _changingLanguage = false,
                                            );
                                          }
                                        }
                                      },
                              );
                            }).toList(growable: false),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsSection(
                          title: 'Text Version',
                          child: Column(
                            children: <Widget>[
                              if (_changingVersion || _changingLanguage)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                )
                              else
                                ...controller.availableVersions.map(
                                  (ResolvedBibleVersion version) {
                                    final selected =
                                        currentVersion?.id == version.id;
                                    return _SettingsOptionTile(
                                      title: version.abbreviation,
                                      subtitle: version.title,
                                      selected: selected,
                                      trailing: version.hasAudio
                                          ? Icon(
                                              Icons.graphic_eq_rounded,
                                              color: palette.accent,
                                            )
                                          : null,
                                      onTap: () async {
                                        if (selected) {
                                          return;
                                        }
                                        setState(() => _changingVersion = true);
                                        try {
                                          await controller.selectVersion(
                                            version.id,
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(
                                              () => _changingVersion = false,
                                            );
                                          }
                                        }
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsSection(
                          title: 'Audio',
                          child: Column(
                            children: <Widget>[
                              SwitchListTile.adaptive(
                                value: controller.isAudioEnabled,
                                onChanged:
                                    controller.currentVersionSupportsAudio
                                        ? controller.setAudioEnabled
                                        : null,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Enable chapter audio',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  controller.currentVersionSupportsAudio
                                      ? 'Playback follows the selected narration profile when available.'
                                      : 'This translation does not expose playable chapter audio.',
                                ),
                                activeThumbColor: palette.accent,
                                activeTrackColor:
                                    palette.accent.withValues(alpha: 0.28),
                              ),
                              const SizedBox(height: 8),
                              if (audioProfiles.length <= 1)
                                _SettingsOptionTile(
                                  title: audioProfiles.first.label,
                                  subtitle:
                                      controller.currentVersionSupportsAudio
                                          ? 'Default narration for this version'
                                          : 'Unavailable for this version',
                                  selected: true,
                                  onTap: controller.currentVersionSupportsAudio
                                      ? () => controller.selectAudioProfile(
                                            audioProfiles.first.id,
                                          )
                                      : null,
                                )
                              else
                                RadioGroup<String>(
                                  groupValue: controller.selectedAudioProfileId,
                                  onChanged: (String? value) {
                                    if (value != null &&
                                        controller
                                            .currentVersionSupportsAudio) {
                                      controller.selectAudioProfile(value);
                                    }
                                  },
                                  child: Column(
                                    children: audioProfiles.map((
                                      BibleAudioProfile profile,
                                    ) {
                                      return RadioListTile<String>(
                                        value: profile.id,
                                        enabled: controller
                                            .currentVersionSupportsAudio,
                                        activeColor: palette.accent,
                                        title: Text(profile.label),
                                        subtitle: Text(
                                          profile.isDramatized
                                              ? 'Narrated with dramatic voice treatment'
                                              : 'Standard narration',
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsSection(
                          title: 'Offline',
                          child: _SettingsOptionTile(
                            title: 'Downloads',
                            subtitle:
                                'Open text and audio downloads for the current Bible setup.',
                            selected: false,
                            trailing: Icon(
                              Icons.download_rounded,
                              color: palette.accent,
                            ),
                            onTap: widget.onOpenDownloads,
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
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.panelGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsOptionTile extends StatelessWidget {
  const _SettingsOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? palette.selectedSurface : palette.secondarySurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected ? palette.cardShadows : palette.smallShadows,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _BibleSplitInfoCard extends StatelessWidget {
  const _BibleSplitInfoCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.panelGradient,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: palette.accentStrong),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.55,
                    color: palette.secondaryMutedText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BibleSearchBar extends StatelessWidget {
  const _BibleSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search Bible books…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: palette.surface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _BooksList extends StatelessWidget {
  const _BooksList({
    required this.books,
    required this.languageCode,
    required this.onRefresh,
    required this.onSelectBook,
  });

  final List<BibleBook> books;
  final String languageCode;
  final Future<void> Function() onRefresh;
  final ValueChanged<BibleBook> onSelectBook;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    final textStyle = _scriptBodyStyle(context, languageCode);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final book = books[index];
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.panelGradient,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: palette.cardShadows,
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              title: Text(book.title, style: textStyle),
              subtitle: Text(
                '${book.chapterCount} chapters',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryMutedText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              trailing: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: palette.accentStrong,
                ),
              ),
              onTap: () => onSelectBook(book),
            ),
          );
        },
      ),
    );
  }
}

class _ChapterGrid extends StatelessWidget {
  const _ChapterGrid({
    required this.book,
    required this.languageCode,
    required this.onSelectChapter,
  });

  final BibleBook book;
  final String languageCode;
  final ValueChanged<int> onSelectChapter;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 132,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.02,
      ),
      itemCount: book.chapterCount,
      itemBuilder: (BuildContext context, int index) {
        final chapterNumber = index + 1;
        return _ChapterSelectionButton(
          chapterNumber: chapterNumber,
          languageCode: languageCode,
          onPressed: () => onSelectChapter(chapterNumber),
        );
      },
    );
  }
}

class _ChapterSelectionButton extends StatelessWidget {
  const _ChapterSelectionButton({
    required this.chapterNumber,
    required this.languageCode,
    required this.onPressed,
    this.isSelected = false,
  });

  final int chapterNumber;
  final String languageCode;
  final VoidCallback onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    final numberStyle = _scriptBodyStyle(
      context,
      languageCode,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ).copyWith(
      color: isSelected ? Colors.white : palette.accentStrong,
      height: 1.1,
    );

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: isSelected ? palette.accent : palette.secondarySurface,
        foregroundColor: isSelected ? Colors.white : palette.accentStrong,
        elevation: 0,
        side: BorderSide(
          color: isSelected ? palette.accent : palette.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      child: Text(
        chapterNumber.toString(),
        style: numberStyle,
      ),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({
    super.key,
    required this.controller,
    required this.onToggleImmersive,
  });

  final BibleController controller;
  final VoidCallback onToggleImmersive;

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView> {
  late final PageController _pageController;
  _SelectedVerseSelection? _selectedVerse;
  bool _runningVerseAction = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.controller.currentChapterNumber - 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefetchVisibleChapters();
    });
  }

  @override
  void didUpdateWidget(covariant _ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.currentChapterNumber !=
            widget.controller.currentChapterNumber ||
        oldWidget.controller.currentBook?.id !=
            widget.controller.currentBook?.id ||
        oldWidget.controller.selectedLanguageCode !=
            widget.controller.selectedLanguageCode ||
        oldWidget.controller.currentVersion?.id !=
            widget.controller.currentVersion?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _prefetchVisibleChapters();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final book = controller.currentBook;
    if (book == null) {
      return const Center(child: Text('No chapter selected'));
    }

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: book.chapterCount,
                onPageChanged: (int pageIndex) {
                  final nextChapterNumber = pageIndex + 1;
                  _clearVerseSelection();
                  if (controller.currentChapterNumber != nextChapterNumber) {
                    controller.goToChapter(nextChapterNumber);
                  }
                  _prefetchVisibleChapters(chapterNumber: nextChapterNumber);
                },
                itemBuilder: (BuildContext context, int index) {
                  final chapterNumber = index + 1;
                  return _ReaderChapterPage(
                    key: ValueKey<String>(
                      '${controller.selectedLanguageCode}:${controller.currentVersion?.id ?? 0}:${book.id}:$chapterNumber',
                    ),
                    languageCode: controller.selectedLanguageCode,
                    future: controller.loadChapter(
                      bookId: book.id,
                      bookTitle: book.title,
                      chapterNumber: chapterNumber,
                    ),
                    selectedVerseNumber:
                        chapterNumber == controller.currentChapterNumber
                            ? _selectedVerse?.verse.number
                            : null,
                    isVerseHighlighted: (int verseNumber) =>
                        controller.isVerseHighlighted(
                      bookId: book.id,
                      chapterNumber: chapterNumber,
                      verseNumber: verseNumber,
                    ),
                    readerTextScale: controller.readerTextScale,
                    onTapSurface: () {
                      if (_selectedVerse != null) {
                        _clearVerseSelection();
                        return;
                      }
                      widget.onToggleImmersive();
                    },
                    onSelectVerse: (Verse verse) {
                      unawaited(
                        _openVerseActionSheet(
                          verse: verse,
                          chapterNumber: chapterNumber,
                        ),
                      );
                    },
                    onScaleText: controller.setReaderTextScale,
                  );
                },
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: controller.immersiveMode
                  ? const SizedBox.shrink()
                  : _ReaderBottomBar(
                      currentBook: book,
                      books: controller.books,
                      chapterNumber: controller.currentChapterNumber,
                      chapterCount: book.chapterCount,
                      languageCode: controller.selectedLanguageCode,
                      onPrevious: controller.currentChapterNumber > 1
                          ? () => _animateToChapter(
                                controller.currentChapterNumber - 1,
                              )
                          : null,
                      onNext:
                          controller.currentChapterNumber < book.chapterCount
                              ? () => _animateToChapter(
                                    controller.currentChapterNumber + 1,
                                  )
                              : null,
                      onOpenNavigator: _openReaderNavigator,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openVerseActionSheet({
    required Verse verse,
    required int chapterNumber,
  }) async {
    if (_runningVerseAction || !mounted) {
      return;
    }

    final controller = widget.controller;
    final currentBook = controller.currentBook;
    if (currentBook == null) {
      return;
    }

    controller.setImmersiveMode(false);
    final selection = _SelectedVerseSelection(
      verse: verse,
      chapterNumber: chapterNumber,
    );
    setState(() {
      _selectedVerse = selection;
    });

    final reference = '${currentBook.title} $chapterNumber:${verse.number}';
    final isHighlighted = controller.isVerseHighlighted(
      bookId: currentBook.id,
      chapterNumber: chapterNumber,
      verseNumber: verse.number,
    );
    final isBookmarked = controller.isVerseBookmarked(
      bookId: currentBook.id,
      chapterNumber: chapterNumber,
      verseNumber: verse.number,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (BuildContext context) {
        return _VerseActionSheet(
          reference: reference,
          verseText: normalizeInlineVerseText(verse),
          languageCode: controller.selectedLanguageCode,
          isHighlighted: isHighlighted,
          isBookmarked: isBookmarked,
          onCopy: () {
            Navigator.of(context).pop();
            unawaited(_copyVerse(selection));
          },
          onFavorite: isBookmarked
              ? null
              : () {
                  Navigator.of(context).pop();
                  unawaited(_favoriteVerse(selection));
                },
          onShare: () {
            Navigator.of(context).pop();
            unawaited(_shareVerse(selection));
          },
          onHighlight: () {
            Navigator.of(context).pop();
            unawaited(_toggleVerseHighlight(selection));
          },
          onTranslate: () {
            Navigator.of(context).pop();
            unawaited(_translateVerse(selection));
          },
        );
      },
    );

    if (mounted) {
      _clearVerseSelection();
    }
  }

  Future<void> _animateToChapter(int chapterNumber) {
    _clearVerseSelection();
    return _pageController.animateToPage(
      chapterNumber - 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openReaderNavigator() async {
    final controller = widget.controller;
    final currentBook = controller.currentBook;
    if (currentBook == null) {
      return;
    }

    final selection = await showModalBottomSheet<_ReaderNavigationSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _ReaderNavigationSheet(
            books: controller.books,
            currentBook: currentBook,
            currentChapter: controller.currentChapterNumber,
            languageCode: controller.selectedLanguageCode,
          ),
        );
      },
    );

    if (selection == null) {
      return;
    }
    _clearVerseSelection();
    if (selection.book.id == currentBook.id) {
      if (selection.chapterNumber != controller.currentChapterNumber) {
        await _animateToChapter(selection.chapterNumber);
      }
      return;
    }

    controller.openReaderPassage(selection.book, selection.chapterNumber);
  }

  void _prefetchVisibleChapters({int? chapterNumber}) {
    widget.controller.prefetchChaptersAround(
      chapterNumber: chapterNumber,
    );
  }

  void _clearVerseSelection() {
    if (_selectedVerse == null) {
      return;
    }
    setState(() {
      _selectedVerse = null;
    });
  }

  Future<void> _copyVerse(_SelectedVerseSelection selection) async {
    if (!mounted) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: normalizeInlineVerseText(selection.verse)),
    );
    if (!mounted) {
      return;
    }
    showClaySnackBar(context, 'Verse text copied', type: ClaySnackType.success);
  }

  Future<void> _translateVerse(_SelectedVerseSelection selection) async {
    if (!mounted) {
      return;
    }

    setState(() => _runningVerseAction = true);
    try {
      final translation = await widget.controller.lookupEnglishVerse(
        selection.verse,
        chapterNumber: selection.chapterNumber,
      );
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        showDragHandle: false,
        builder: (BuildContext context) {
          final palette = _biblePalette(context);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Translate to English',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translation.reference,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translation.versionLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      translation.text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.7,
                            fontSize: 19,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      if (mounted) {
        setState(() => _runningVerseAction = false);
      }
    }
  }

  Future<void> _favoriteVerse(_SelectedVerseSelection selection) async {
    if (!mounted) {
      return;
    }

    setState(() => _runningVerseAction = true);
    try {
      await widget.controller.addBookmarkForVerse(
        selection.verse,
        chapterNumber: selection.chapterNumber,
      );
      if (!mounted) {
        return;
      }
      showClaySnackBar(context, 'Verse added to favorites', type: ClaySnackType.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      if (mounted) {
        setState(() => _runningVerseAction = false);
      }
    }
  }

  Future<void> _shareVerse(_SelectedVerseSelection selection) async {
    if (!mounted) {
      return;
    }

    setState(() => _runningVerseAction = true);
    try {
      final shareText = widget.controller.buildVerseShareText(
        selection.verse,
        chapterNumber: selection.chapterNumber,
      );
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      if (mounted) {
        setState(() => _runningVerseAction = false);
      }
    }
  }

  Future<void> _toggleVerseHighlight(_SelectedVerseSelection selection) async {
    if (!mounted) {
      return;
    }

    final controller = widget.controller;
    final bookId = controller.currentBook?.id;
    if (bookId == null) {
      return;
    }

    final isHighlighted = controller.toggleVerseHighlight(
      bookId: bookId,
      chapterNumber: selection.chapterNumber,
      verse: selection.verse,
    );
    if (!mounted) {
      return;
    }
    showClaySnackBar(
      context,
      isHighlighted ? 'Verse highlighted' : 'Highlight removed',
      type: ClaySnackType.success,
    );
  }
}

class _ReaderChapterPage extends StatefulWidget {
  const _ReaderChapterPage({
    super.key,
    required this.languageCode,
    required this.future,
    required this.selectedVerseNumber,
    required this.isVerseHighlighted,
    required this.readerTextScale,
    required this.onTapSurface,
    required this.onSelectVerse,
    required this.onScaleText,
  });

  final String languageCode;
  final Future<ChapterResponse> future;
  final int? selectedVerseNumber;
  final bool Function(int verseNumber) isVerseHighlighted;
  final double readerTextScale;
  final VoidCallback onTapSurface;
  final ValueChanged<Verse> onSelectVerse;
  final ValueChanged<double> onScaleText;

  @override
  State<_ReaderChapterPage> createState() => _ReaderChapterPageState();
}

class _ReaderChapterPageState extends State<_ReaderChapterPage> {
  final ScrollController _scrollController = ScrollController();
  double _scaleStart = 1;
  double? _liveTextScale;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReaderChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final liveTextScale = _liveTextScale;
    if (liveTextScale != null &&
        (widget.readerTextScale - liveTextScale).abs() < 0.001) {
      _liveTextScale = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChapterResponse>(
      future: widget.future,
      builder: (
        BuildContext context,
        AsyncSnapshot<ChapterResponse> snapshot,
      ) {
        final palette = _biblePalette(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return clayLoadingCenter(context);
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: palette.cardShadows,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    formatDisplayError(snapshot.error!),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          );
        }

        final chapter = snapshot.data;
        if (chapter == null || chapter.verses.isEmpty) {
          final langLabel =
              bibleLanguageForCode(widget.languageCode).englishLabel;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.menu_book_rounded,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Bible not available in $langLabel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A digital Bible for this language has not been found yet. Check back later.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final effectiveTextScale = _liveTextScale ?? widget.readerTextScale;
        final scaledBodySize = 22 * effectiveTextScale;
        final scaledNumberSize = 14 * effectiveTextScale;
        final selectionColor = palette.selectionOverlay;
        final highlightColor = palette.highlightOverlay;
        final bodyStyle = _scriptBodyStyle(
          context,
          widget.languageCode,
          fontSize: scaledBodySize,
          fontWeight: FontWeight.w400,
        ).copyWith(
          color: palette.text,
          height: 1.78,
        );
        final numberStyle =
            (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
                .copyWith(
          fontSize: scaledNumberSize * 0.92,
          height: 1,
          fontWeight: FontWeight.w800,
          color: palette.verseNumber,
          fontFamilyFallback:
              bibleLanguageForCode(widget.languageCode).fontFamilyFallback,
        );

        final verseSpans = <InlineSpan>[];
        final verseRanges = <_VerseTextRange>[];
        var cursor = 0;

        for (final verse in chapter.verses) {
          final normalizedText = normalizeInlineVerseText(verse);
          if (normalizedText.isEmpty) {
            continue;
          }

          if (verseSpans.isNotEmpty) {
            verseSpans.add(TextSpan(text: inlineVerseGap, style: bodyStyle));
            cursor += inlineVerseGap.length;
          }

          final selected = verse.number == widget.selectedVerseNumber;
          final highlighted = widget.isVerseHighlighted(verse.number);
          final backgroundColor = selected
              ? selectionColor
              : highlighted
                  ? highlightColor
                  : null;
          final verseText = '${verse.number} $normalizedText';
          verseRanges.add(
            _VerseTextRange(
              verse: verse,
              start: cursor,
              end: cursor + verseText.length,
            ),
          );
          cursor += verseText.length;

          verseSpans.add(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${verse.number} ',
                  style: numberStyle.copyWith(
                    backgroundColor: backgroundColor,
                  ),
                ),
                TextSpan(
                  text: normalizedText,
                  style: bodyStyle.copyWith(
                    backgroundColor: backgroundColor,
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final textSpan = TextSpan(children: verseSpans);
            const horizontalPadding = 40.0;
            final maxTextWidth = (constraints.maxWidth - horizontalPadding)
                .clamp(0.0, double.infinity);
            final textPainter = TextPainter(
              text: textSpan,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: maxTextWidth);

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onTapSurface,
              onLongPressStart: (LongPressStartDetails details) {
                final verse = _verseAtOffset(
                  localPosition: details.localPosition,
                  textPainter: textPainter,
                  verseRanges: verseRanges,
                );
                if (verse != null) {
                  widget.onSelectVerse(verse);
                }
              },
              onScaleStart: (ScaleStartDetails details) {
                _scaleStart = _liveTextScale ?? widget.readerTextScale;
              },
              onScaleUpdate: (ScaleUpdateDetails details) {
                if (details.pointerCount < 2) {
                  return;
                }
                final nextScale = (_scaleStart * details.scale).clamp(
                  BibleController.minReaderTextScale,
                  BibleController.maxReaderTextScale,
                );
                if (_liveTextScale != null &&
                    (nextScale - _liveTextScale!).abs() < 0.001) {
                  return;
                }
                setState(() {
                  _liveTextScale = nextScale;
                });
              },
              onScaleEnd: (ScaleEndDetails details) {
                final liveTextScale = _liveTextScale;
                if (liveTextScale == null) {
                  return;
                }
                widget.onScaleText(liveTextScale);
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: RichText(
                  text: textSpan,
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Verse? _verseAtOffset({
    required Offset localPosition,
    required TextPainter textPainter,
    required List<_VerseTextRange> verseRanges,
  }) {
    if (verseRanges.isEmpty) {
      return null;
    }

    final adjustedPosition = Offset(
      (localPosition.dx - 20).clamp(0.0, textPainter.width),
      (localPosition.dy - 12 + _scrollController.offset)
          .clamp(0.0, textPainter.height),
    );
    final textOffset =
        textPainter.getPositionForOffset(adjustedPosition).offset;

    for (final verseRange in verseRanges) {
      if (textOffset >= verseRange.start && textOffset < verseRange.end) {
        return verseRange.verse;
      }
    }

    for (final verseRange in verseRanges) {
      if (textOffset < verseRange.start) {
        return verseRange.verse;
      }
    }
    return verseRanges.last.verse;
  }
}

class _VerseTextRange {
  const _VerseTextRange({
    required this.verse,
    required this.start,
    required this.end,
  });

  final Verse verse;
  final int start;
  final int end;
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.currentBook,
    required this.books,
    required this.chapterNumber,
    required this.chapterCount,
    required this.languageCode,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenNavigator,
  });

  final BibleBook currentBook;
  final List<BibleBook> books;
  final int chapterNumber;
  final int chapterCount;
  final String languageCode;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpenNavigator;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 380;
    final palette = _biblePalette(context);

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          0,
          compact ? 10 : 12,
          compact ? 10 : 12,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: palette.bottomBarSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: palette.bottomBarShadows,
        ),
        child: Row(
          children: <Widget>[
            _ReaderArrowButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: onPrevious,
              compact: compact,
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onOpenNavigator,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: 1,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                currentBook.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _scriptBodyStyle(
                                  context,
                                  languageCode,
                                  fontSize: compact ? 17 : 18,
                                  fontWeight: FontWeight.w700,
                                ).copyWith(height: 1.15),
                              ),
                            ),
                            SizedBox(width: compact ? 4 : 6),
                            Icon(
                              Icons.unfold_more_rounded,
                              size: compact ? 16 : 18,
                              color: palette.accentStrong,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$chapterNumber / $chapterCount',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: palette.secondaryMutedText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 10 : 11,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _ReaderArrowButton(
              icon: Icons.arrow_forward_ios_rounded,
              onPressed: onNext,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderNavigationSheet extends StatefulWidget {
  const _ReaderNavigationSheet({
    required this.books,
    required this.currentBook,
    required this.currentChapter,
    required this.languageCode,
  });

  final List<BibleBook> books;
  final BibleBook currentBook;
  final int currentChapter;
  final String languageCode;

  @override
  State<_ReaderNavigationSheet> createState() => _ReaderNavigationSheetState();
}

class _ReaderNavigationSheetState extends State<_ReaderNavigationSheet> {
  BibleBook? _activeBook;
  bool _showBookList = false;

  @override
  void initState() {
    super.initState();
    _activeBook = widget.currentBook;
  }

  @override
  Widget build(BuildContext context) {
    final activeBook = _activeBook;
    final palette = _biblePalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: activeBook == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() => _showBookList = true);
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  activeBook.title,
                                  style: _scriptBodyStyle(
                                    context,
                                    widget.languageCode,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ).copyWith(height: 1.2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: palette.accentStrong,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _showBookList
                          ? 'Choose a book, then a chapter.'
                          : '${activeBook.chapterCount} chapters. Tap the book name to switch books.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: palette.secondaryMutedText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _showBookList
                          ? ListView.separated(
                              itemCount: widget.books.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int index) {
                                final book = widget.books[index];
                                final selected = book.id == activeBook.id;
                                return _SettingsOptionTile(
                                  title: book.title,
                                  subtitle: '${book.chapterCount} chapters',
                                  selected: selected,
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: palette.accent,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _activeBook = book;
                                      _showBookList = false;
                                    });
                                  },
                                );
                              },
                            )
                          : GridView.builder(
                              itemCount: activeBook.chapterCount,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 112,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.02,
                              ),
                              itemBuilder: (BuildContext context, int index) {
                                final candidateChapter = index + 1;
                                return _ChapterSelectionButton(
                                  chapterNumber: candidateChapter,
                                  languageCode: widget.languageCode,
                                  isSelected: activeBook.id ==
                                          widget.currentBook.id &&
                                      candidateChapter == widget.currentChapter,
                                  onPressed: () {
                                    Navigator.of(context).pop(
                                      _ReaderNavigationSelection(
                                        book: activeBook,
                                        chapterNumber: candidateChapter,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _VerseActionSheet extends StatelessWidget {
  const _VerseActionSheet({
    required this.reference,
    required this.verseText,
    required this.languageCode,
    required this.isHighlighted,
    required this.isBookmarked,
    required this.onCopy,
    required this.onFavorite,
    required this.onShare,
    required this.onHighlight,
    required this.onTranslate,
  });

  final String reference;
  final String verseText;
  final String languageCode;
  final bool isHighlighted;
  final bool isBookmarked;
  final VoidCallback onCopy;
  final VoidCallback? onFavorite;
  final VoidCallback onShare;
  final VoidCallback onHighlight;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reference,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.warmLabel,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: palette.secondarySurface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: palette.cardShadows,
                  ),
                  child: Text(
                    verseText,
                    style: _scriptBodyStyle(
                      context,
                      languageCode,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ).copyWith(
                      color: palette.text,
                      height: 1.8,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _VerseActionSheetTile(
                  icon: Icons.content_copy_rounded,
                  label: 'Copy text',
                  subtitle: 'Copy only the verse text to the clipboard.',
                  onTap: onCopy,
                ),
                const SizedBox(height: 10),
                _VerseActionSheetTile(
                  icon: isBookmarked
                      ? Icons.check_circle_rounded
                      : Icons.favorite_border_rounded,
                  label:
                      isBookmarked ? 'Saved to favorites' : 'Add to favorites',
                  subtitle: isBookmarked
                      ? 'This verse is already in your saved list.'
                      : 'Save this verse for quick access later.',
                  onTap: onFavorite,
                ),
                const SizedBox(height: 10),
                _VerseActionSheetTile(
                  icon: isHighlighted
                      ? Icons.highlight_remove_rounded
                      : Icons.highlight_alt_rounded,
                  label: isHighlighted ? 'Remove highlight' : 'Highlight verse',
                  subtitle: isHighlighted
                      ? 'Clear the saved highlight from this verse.'
                      : 'Keep this verse highlighted in the reader.',
                  onTap: onHighlight,
                ),
                const SizedBox(height: 10),
                _VerseActionSheetTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Share verse',
                  subtitle: 'Share the verse with its reference and link.',
                  onTap: onShare,
                ),
                const SizedBox(height: 10),
                _VerseActionSheetTile(
                  icon: Icons.translate_rounded,
                  label: 'Translate to English',
                  subtitle: 'Open the matching English verse in a sheet.',
                  onTap: onTranslate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerseActionSheetTile extends StatelessWidget {
  const _VerseActionSheetTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final palette = _biblePalette(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: enabled ? palette.secondarySurface : palette.disabledSurface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: enabled ? palette.smallShadows : null,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: enabled ? palette.accentSoft : palette.disabledSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: enabled ? palette.accentStrong : palette.disabledText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color:
                                enabled ? palette.text : palette.disabledText,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: enabled
                                ? palette.secondaryMutedText
                                : palette.disabledText,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? palette.warmLabel : palette.disabledText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderActionShell extends StatelessWidget {
  const _HeaderActionShell({
    required this.child,
    this.size = 52,
  });

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.actionGradient,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: palette.actionShadows,
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white, size: 26),
        child: Center(child: child),
      ),
    );
  }
}

class _HeaderIconShell extends StatelessWidget {
  const _HeaderIconShell({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 52,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _biblePalette(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.secondaryActionGradient,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: palette.smallShadows,
            ),
            child: Icon(
              icon,
              color: palette.accentStrong,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderArrowButton extends StatelessWidget {
  const _ReaderArrowButton({
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final palette = _biblePalette(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: compact ? 40 : 44,
          height: compact ? 38 : 40,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette.actionGradient,
                  )
                : null,
            color: enabled ? null : palette.disabledSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled ? palette.actionShadows : null,
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : palette.disabledText,
            size: compact ? 17 : 18,
          ),
        ),
      ),
    );
  }
}

class _ReaderNavigationSelection {
  const _ReaderNavigationSelection({
    required this.book,
    required this.chapterNumber,
  });

  final BibleBook book;
  final int chapterNumber;
}

class _SelectedVerseSelection {
  const _SelectedVerseSelection({
    required this.verse,
    required this.chapterNumber,
  });

  final Verse verse;
  final int chapterNumber;
}

class _BiblePalette {
  const _BiblePalette({
    required this.pageGradient,
    required this.panelGradient,
    required this.secondaryActionGradient,
    required this.actionGradient,
    required this.surface,
    required this.secondarySurface,
    required this.selectedSurface,
    required this.border,
    required this.selectedSurfaceBorder,
    required this.progressTrack,
    required this.handle,
    required this.text,
    required this.mutedText,
    required this.secondaryMutedText,
    required this.warmLabel,
    required this.verseNumber,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.bottomBarSurface,
    required this.bottomBarBorder,
    required this.selectionOverlay,
    required this.highlightOverlay,
    required this.disabledSurface,
    required this.disabledBorder,
    required this.disabledText,
    required this.cardShadows,
    required this.smallShadows,
    required this.bottomBarShadows,
    required this.actionShadows,
  });

  final List<Color> pageGradient;
  final List<Color> panelGradient;
  final List<Color> secondaryActionGradient;
  final List<Color> actionGradient;
  final Color surface;
  final Color secondarySurface;
  final Color selectedSurface;
  final Color border;
  final Color selectedSurfaceBorder;
  final Color progressTrack;
  final Color handle;
  final Color text;
  final Color mutedText;
  final Color secondaryMutedText;
  final Color warmLabel;
  final Color verseNumber;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color bottomBarSurface;
  final Color bottomBarBorder;
  final Color selectionOverlay;
  final Color highlightOverlay;
  final Color disabledSurface;
  final Color disabledBorder;
  final Color disabledText;
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> smallShadows;
  final List<BoxShadow> bottomBarShadows;
  final List<BoxShadow> actionShadows;
}

_BiblePalette _biblePalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const _BiblePalette(
      pageGradient: <Color>[Color(0xFF0F1714), Color(0xFF111D19)],
      panelGradient: <Color>[Color(0xFF1A231F), Color(0xFF141B18)],
      secondaryActionGradient: <Color>[Color(0xFF22312A), Color(0xFF18231F)],
      actionGradient: <Color>[Color(0xFF2A7C62), Color(0xFF143B30)],
      surface: Color(0xFF141B18),
      secondarySurface: Color(0xFF1E2824),
      selectedSurface: Color(0xFF22312A),
      border: Color(0xFF31403A),
      selectedSurfaceBorder: Color(0xFF476558),
      progressTrack: Color(0xFF27352F),
      handle: Color(0xFF3E4C46),
      text: Color(0xFFE8F0EB),
      mutedText: Color(0xFFAAB7B0),
      secondaryMutedText: Color(0xFF98A49E),
      warmLabel: Color(0xFFD8B88E),
      verseNumber: Color(0xFFD6B18A),
      accent: Color(0xFF8FD8B5),
      accentStrong: Color(0xFFB4E7CA),
      accentSoft: Color(0xFF263A32),
      bottomBarSurface: Color(0xFF1A231F),
      bottomBarBorder: Color(0xFF31403A),
      selectionOverlay: Color(0x55588E74),
      highlightOverlay: Color(0x55506E58),
      disabledSurface: Color(0xFF303733),
      disabledBorder: Color(0xFF414743),
      disabledText: Color(0xFF79817D),
      cardShadows: <BoxShadow>[
        BoxShadow(color: Color(0x6B000000), blurRadius: 22, offset: Offset(0, 9)),
        BoxShadow(color: Color(0x2E000000), blurRadius: 44, spreadRadius: -6, offset: Offset(0, 20)),
        BoxShadow(color: Color(0x0EFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
      ],
      smallShadows: <BoxShadow>[
        BoxShadow(color: Color(0x52000000), blurRadius: 12, offset: Offset(0, 5)),
        BoxShadow(color: Color(0x08FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-1, -2)),
      ],
      bottomBarShadows: <BoxShadow>[
        BoxShadow(color: Color(0x73000000), blurRadius: 28, offset: Offset(0, 12)),
        BoxShadow(color: Color(0x2E000000), blurRadius: 50, spreadRadius: -6, offset: Offset(0, 22)),
        BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
      ],
      actionShadows: <BoxShadow>[
        BoxShadow(color: Color(0x8C000000), blurRadius: 16, offset: Offset(0, 8)),
        BoxShadow(color: Color(0x38000000), blurRadius: 32, spreadRadius: -4, offset: Offset(0, 16)),
        BoxShadow(color: Color(0x10FFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -3)),
      ],
    );
  }

  return const _BiblePalette(
    pageGradient: <Color>[Color(0xFFF7F0E3), Color(0xFFFDFBF6)],
    panelGradient: <Color>[Color(0xFFFFFCF7), Color(0xFFF3ECE0)],
    secondaryActionGradient: <Color>[Color(0xFFFFFEFB), Color(0xFFF0E7D8)],
    actionGradient: <Color>[Color(0xFF1D5B49), Color(0xFF0F4032)],
    surface: Color(0xFFFFFBF5),
    secondarySurface: Color(0xFFF7F0E3),
    selectedSurface: Color(0xFFE3F2EB),
    border: Color(0xFFE4D8C5),
    selectedSurfaceBorder: Color(0xFFB9D3C6),
    progressTrack: Color(0xFFE7DDD0),
    handle: Color(0xFFD9CDB8),
    text: Color(0xFF1F241F),
    mutedText: Color(0xFF6C6A65),
    secondaryMutedText: Color(0xFF6E6A63),
    warmLabel: Color(0xFF725D43),
    verseNumber: Color(0xFF8A6642),
    accent: Color(0xFF17624D),
    accentStrong: Color(0xFF195241),
    accentSoft: Color(0xFFE4EFE9),
    bottomBarSurface: Color(0xFFF8F2E7),
    bottomBarBorder: Color(0xFFE1D4BF),
    selectionOverlay: Color(0x55D6BC78),
    highlightOverlay: Color(0x3FD7C16B),
    disabledSurface: Color(0xFFE8E1D5),
    disabledBorder: Color(0xFFD7CCBC),
    disabledText: Color(0xFFA59C8F),
    cardShadows: <BoxShadow>[
      BoxShadow(color: Color(0x381A5A47), blurRadius: 22, offset: Offset(0, 9)),
      BoxShadow(color: Color(0x1A1A5A47), blurRadius: 44, spreadRadius: -6, offset: Offset(0, 20)),
      BoxShadow(color: Color(0xE6FFFFFF), blurRadius: 0, spreadRadius: 2, offset: Offset(-3, -3)),
    ],
    smallShadows: <BoxShadow>[
      BoxShadow(color: Color(0x2E1A5A47), blurRadius: 12, offset: Offset(0, 5)),
      BoxShadow(color: Color(0xEBFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -2)),
    ],
    bottomBarShadows: <BoxShadow>[
      BoxShadow(color: Color(0x331A5A47), blurRadius: 28, offset: Offset(0, 12)),
      BoxShadow(color: Color(0x171A5A47), blurRadius: 50, spreadRadius: -6, offset: Offset(0, 22)),
      BoxShadow(color: Color(0xE0FFFFFF), blurRadius: 0, spreadRadius: 2, offset: Offset(-2, -2)),
    ],
    actionShadows: <BoxShadow>[
      BoxShadow(color: Color(0x590F3F32), blurRadius: 16, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x290F3F32), blurRadius: 32, spreadRadius: -4, offset: Offset(0, 16)),
      BoxShadow(color: Color(0x2EFFFFFF), blurRadius: 0, spreadRadius: 1, offset: Offset(-2, -3)),
    ],
  );
}

TextStyle _scriptBodyStyle(
  BuildContext context,
  String languageCode, {
  double fontSize = 18,
  FontWeight fontWeight = FontWeight.w500,
}) {
  final option = bibleLanguageForCode(languageCode);
  final preferredFontFamily = _preferredScriptFontFamily(option);
  return (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
    fontSize: fontSize,
    height: 1.65,
    fontWeight: fontWeight,
    fontFamily: preferredFontFamily,
    fontFamilyFallback: option.fontFamilyFallback
        .where((String fontFamily) => fontFamily != preferredFontFamily)
        .toList(growable: false),
  );
}

String? _preferredScriptFontFamily(BibleLanguageOption option) {
  if (option.fontFamilyFallback.isEmpty) {
    return null;
  }

  if (option.code == 'en') {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        return 'Noto Serif';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Georgia';
      case TargetPlatform.windows:
        return 'Times New Roman';
    }
  }

  return option.fontFamilyFallback.first;
}
