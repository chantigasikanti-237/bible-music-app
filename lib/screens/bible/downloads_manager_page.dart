import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/bible_languages.dart';
import '../../theme/clay_decorations.dart';
import '../../controllers/bible_controller.dart';
import '../../models/bible_catalog.dart';
import '../../services/offline_bible_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/adaptive_layout.dart';

class DownloadsManagerPage extends StatefulWidget {
  const DownloadsManagerPage({
    super.key,
    this.inlineAudioUrl,
  });

  final String? inlineAudioUrl;

  @override
  State<DownloadsManagerPage> createState() => _DownloadsManagerPageState();
}

class _BookProgress {
  const _BookProgress({required this.done, required this.total});
  final int done;
  final int total;
  double get fraction => total > 0 ? done / total : 0;
}

class _WholeBibleProgress {
  const _WholeBibleProgress({
    required this.chaptersDone,
    required this.chaptersTotal,
    required this.currentBookTitle,
  });
  final int chaptersDone;
  final int chaptersTotal;
  final String currentBookTitle;
  double get fraction => chaptersTotal > 0 ? chaptersDone / chaptersTotal : 0;
}

class _DownloadsManagerPageState extends State<DownloadsManagerPage> {
  final Set<String> _textLoading = <String>{};
  final Set<String> _audioLoading = <String>{};
  final Set<String> _bookLoading = <String>{};
  final Set<String> _wholeBibleLoading = <String>{};
  int _refreshTick = 0;

  @override
  Widget build(BuildContext context) {
    final bibleController = context.watch<BibleController>();
    final currentPassageId = bibleController.currentPassageId;
    final introCard = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFCF7),
            Color(0xFFF0E9DE),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5D9C5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Offline Library',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              currentPassageId == null
                  ? 'Open a chapter first. Text downloads are ready now, and audio downloads unlock as soon as a chapter is open.'
                  : 'Text download saves the selected translation. Audio download stores the current chapter for offline playback.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );

    final currentBook = bibleController.currentBook;

    final downloadsList = ListView(
      children: <Widget>[
        for (final BibleLanguageOption option in bibleLanguageOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _DownloadLanguageCard(
              key: ValueKey<String>('${option.code}:$_refreshTick'),
              option: option,
              canDownloadAudio: currentPassageId != null,
              canDownloadBook: currentBook != null,
              currentBookTitle: currentBook?.title,
              isTextLoading: _textLoading.contains(option.code),
              isAudioLoading: _audioLoading.contains(option.code),
              isBookLoading: _bookLoading.contains(option.code),
              isWholeBibleLoading: _wholeBibleLoading.contains(option.code),
              onDownloadText: () => _downloadText(context, option.code),
              onDownloadAudio: currentPassageId == null
                  ? null
                  : () => _downloadAudio(context, option.code),
              onDownloadBook: currentBook == null
                  ? null
                  : () => _downloadBook(context, option.code),
              onDownloadWholeBible: () =>
                  _downloadWholeBible(context, option.code),
            ),
          ),
      ],
    );

    return AdaptiveScaffold(
      backgroundColor: const Color(0xFFF6F1E7),
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        if (!layout.useTwoPane) {
          return Padding(
            padding: layout.pagePadding,
            child: Column(
              children: <Widget>[
                introCard,
                const SizedBox(height: 14),
                Expanded(child: downloadsList),
              ],
            ),
          );
        }

        return Padding(
          padding: layout.pagePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: layout.splitSecondaryFlex,
                child: introCard,
              ),
              SizedBox(width: layout.paneSpacing),
              Expanded(
                flex: layout.splitPrimaryFlex,
                child: downloadsList,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadText(BuildContext context, String languageCode) async {
    setState(() {
      _textLoading.add(languageCode);
    });

    try {
      await context
          .read<BibleController>()
          .downloadTextForLanguage(languageCode);
      if (!context.mounted) {
        return;
      }
      showClaySnackBar(context, '${bibleLanguageForCode(languageCode).nativeLabel} text saved offline', type: ClaySnackType.success);
      setState(() {
        _refreshTick += 1;
      });
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _textLoading.remove(languageCode);
        });
      }
    }
  }

  Future<void> _downloadAudio(BuildContext context, String languageCode) async {
    setState(() {
      _audioLoading.add(languageCode);
    });

    try {
      await context.read<BibleController>().downloadAudioForLanguage(
            languageCode,
            inlineAudioUrl: widget.inlineAudioUrl,
          );
      if (!context.mounted) {
        return;
      }
      showClaySnackBar(context, '${bibleLanguageForCode(languageCode).nativeLabel} audio is ready offline', type: ClaySnackType.success);
      setState(() {
        _refreshTick += 1;
      });
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      if (mounted) {
        setState(() {
          _audioLoading.remove(languageCode);
        });
      }
    }
  }

  Future<void> _downloadBook(BuildContext context, String languageCode) async {
    final bibleController = context.read<BibleController>();
    final currentBook = bibleController.currentBook;
    if (currentBook == null) return;

    setState(() => _bookLoading.add(languageCode));

    final progress = ValueNotifier<_BookProgress>(
      _BookProgress(done: 0, total: currentBook.chapterCount),
    );
    bool cancelled = false;

    if (context.mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BookDownloadDialog(
          bookTitle: currentBook.title,
          progress: progress,
          onCancel: () {
            cancelled = true;
            Navigator.of(context).maybePop();
          },
        ),
      ));
    }

    try {
      await bibleController.downloadBookForLanguage(
        languageCode,
        onProgress: (int done, int total) {
          progress.value = _BookProgress(done: done, total: total);
        },
        isCancelled: () => cancelled,
      );
      if (!context.mounted) return;
      if (!cancelled) {
        Navigator.of(context).maybePop();
        showClaySnackBar(context, '${bibleLanguageForCode(languageCode).nativeLabel}: ${currentBook.title} saved offline', type: ClaySnackType.success);
        setState(() => _refreshTick += 1);
      }
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      progress.dispose();
      if (mounted) setState(() => _bookLoading.remove(languageCode));
    }
  }

  Future<void> _downloadWholeBible(
    BuildContext context,
    String languageCode,
  ) async {
    final bibleController = context.read<BibleController>();
    final catalog = await bibleController.ensureCatalogForLanguage(
      languageCode,
    );
    final totalChapters = catalog.books.fold<int>(
      0,
      (sum, book) => sum + book.chapterCount,
    );

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download whole Bible?'),
        content: Text(
          'This downloads all ${catalog.books.length} books '
          '(~$totalChapters chapters) of text and audio for '
          '${bibleLanguageForCode(languageCode).nativeLabel}. This can take '
          'a while and use significant storage. Continue?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _wholeBibleLoading.add(languageCode));

    final progress = ValueNotifier<_WholeBibleProgress>(
      const _WholeBibleProgress(
        chaptersDone: 0,
        chaptersTotal: 0,
        currentBookTitle: '',
      ),
    );
    bool cancelled = false;

    if (context.mounted) {
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _WholeBibleDownloadDialog(
          progress: progress,
          onCancel: () {
            cancelled = true;
            Navigator.of(context).maybePop();
          },
        ),
      ));
    }

    try {
      await bibleController.downloadWholeBibleForLanguage(
        languageCode,
        onProgress: (int chaptersDone, int chaptersTotal, String bookTitle) {
          progress.value = _WholeBibleProgress(
            chaptersDone: chaptersDone,
            chaptersTotal: chaptersTotal,
            currentBookTitle: bookTitle,
          );
        },
        isCancelled: () => cancelled,
      );
      if (!context.mounted) return;
      if (!cancelled) {
        Navigator.of(context).maybePop();
        showClaySnackBar(
          context,
          '${bibleLanguageForCode(languageCode).nativeLabel}: whole Bible saved offline',
          type: ClaySnackType.success,
        );
        setState(() => _refreshTick += 1);
      }
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      showClaySnackBar(context, formatDisplayError(error), type: ClaySnackType.error);
    } finally {
      progress.dispose();
      if (mounted) setState(() => _wholeBibleLoading.remove(languageCode));
    }
  }
}

class _DownloadLanguageCard extends StatelessWidget {
  const _DownloadLanguageCard({
    super.key,
    required this.option,
    required this.canDownloadAudio,
    required this.canDownloadBook,
    required this.isTextLoading,
    required this.isAudioLoading,
    required this.isBookLoading,
    required this.isWholeBibleLoading,
    required this.onDownloadText,
    required this.onDownloadAudio,
    required this.onDownloadBook,
    required this.onDownloadWholeBible,
    this.currentBookTitle,
  });

  final BibleLanguageOption option;
  final bool canDownloadAudio;
  final bool canDownloadBook;
  final bool isTextLoading;
  final bool isAudioLoading;
  final bool isBookLoading;
  final bool isWholeBibleLoading;
  final VoidCallback onDownloadText;
  final VoidCallback? onDownloadAudio;
  final VoidCallback? onDownloadBook;
  final VoidCallback onDownloadWholeBible;
  final String? currentBookTitle;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<BibleController>();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFCF7),
            Color(0xFFF3ECE0),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE4D8C5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: FutureBuilder<_DownloadCardData>(
        future: _loadCardData(controller),
        builder: (
          BuildContext context,
          AsyncSnapshot<_DownloadCardData> snapshot,
        ) {
          final data = snapshot.data;
          final sourceLabel = data?.sourceLabel ?? option.fallbackSourceLabel;
          final status = data?.status;
          final errorText =
              snapshot.hasError ? formatDisplayError(snapshot.error!) : null;

          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            option.nativeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontFamilyFallback: option.fontFamilyFallback,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sourceLabel,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF6B675F),
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                  ],
                ),
                if (errorText != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFEA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      errorText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9A3B2D),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _StatusPill(
                      label: status?.hasCatalog == true
                          ? 'Library ready'
                          : 'Library pending',
                      color: status?.hasCatalog == true
                          ? const Color(0xFFDDF1E6)
                          : const Color(0xFFF2E7D6),
                      textColor: const Color(0xFF1C4B3C),
                    ),
                    _StatusPill(
                      label: status?.hasCurrentText == true
                          ? 'Chapter saved'
                          : 'Chapter not saved',
                      color: status?.hasCurrentText == true
                          ? const Color(0xFFDDF1E6)
                          : const Color(0xFFF2E7D6),
                      textColor: const Color(0xFF1C4B3C),
                    ),
                    _StatusPill(
                      label: status?.hasCurrentAudio == true
                          ? 'Audio ready'
                          : 'Audio pending',
                      color: status?.hasCurrentAudio == true
                          ? const Color(0xFFDDF1E6)
                          : const Color(0xFFF2E7D6),
                      textColor: const Color(0xFF1C4B3C),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.tonalIcon(
                          onPressed: isTextLoading ? null : onDownloadText,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD5ECE2),
                            foregroundColor: const Color(0xFF184E3E),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: isTextLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Icon(Icons.description_outlined),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Download Text',
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: isAudioLoading || !canDownloadAudio
                              ? null
                              : onDownloadAudio,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF18765B),
                            disabledBackgroundColor: const Color(0xFFE5DED1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: isAudioLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download_for_offline_outlined),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Download Audio',
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonalIcon(
                    onPressed: isBookLoading || !canDownloadBook
                        ? null
                        : onDownloadBook,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE4EDF9),
                      foregroundColor: const Color(0xFF1A3A6B),
                      disabledBackgroundColor: const Color(0xFFE5DED1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: isBookLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.library_books_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currentBookTitle != null
                            ? 'Download $currentBookTitle (all chapters)'
                            : 'Download Book',
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (data?.wholeBibleDownloaded == true)
                  const _StatusPill(
                    label: 'Whole Bible downloaded',
                    color: Color(0xFFDDF1E6),
                    textColor: Color(0xFF1C4B3C),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.tonalIcon(
                      onPressed:
                          isWholeBibleLoading ? null : onDownloadWholeBible,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF3E6D8),
                        foregroundColor: const Color(0xFF6B3F1A),
                        disabledBackgroundColor: const Color(0xFFE5DED1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: isWholeBibleLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Download whole Bible (OT+NT, with audio)',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_DownloadCardData> _loadCardData(BibleController controller) async {
    final ResolvedBibleCatalog catalog =
        await controller.ensureCatalogForLanguage(option.code);
    final OfflineLanguageStatus status =
        await controller.getOfflineStatusForLanguage(option.code);
    final bool wholeBibleDownloaded =
        await controller.isWholeBibleDownloadedForLanguage(option.code);
    return _DownloadCardData(
      sourceLabel: catalog.version.sourceLabel,
      status: status,
      wholeBibleDownloaded: wholeBibleDownloaded,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DownloadCardData {
  const _DownloadCardData({
    required this.sourceLabel,
    required this.status,
    required this.wholeBibleDownloaded,
  });

  final String sourceLabel;
  final OfflineLanguageStatus status;
  final bool wholeBibleDownloaded;
}

class _BookDownloadDialog extends StatelessWidget {
  const _BookDownloadDialog({
    required this.bookTitle,
    required this.progress,
    required this.onCancel,
  });

  final String bookTitle;
  final ValueNotifier<_BookProgress> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Downloading $bookTitle'),
      content: ValueListenableBuilder<_BookProgress>(
        valueListenable: progress,
        builder: (_, _BookProgress p, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LinearProgressIndicator(value: p.fraction),
              const SizedBox(height: 10),
              Text(
                '${p.done} / ${p.total} chapters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _WholeBibleDownloadDialog extends StatelessWidget {
  const _WholeBibleDownloadDialog({
    required this.progress,
    required this.onCancel,
  });

  final ValueNotifier<_WholeBibleProgress> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading whole Bible'),
      content: ValueListenableBuilder<_WholeBibleProgress>(
        valueListenable: progress,
        builder: (_, _WholeBibleProgress p, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LinearProgressIndicator(value: p.fraction),
              const SizedBox(height: 10),
              Text(
                p.currentBookTitle.isEmpty
                    ? 'Starting…'
                    : '${p.currentBookTitle} — ${p.chaptersDone} / ${p.chaptersTotal} chapters overall',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
