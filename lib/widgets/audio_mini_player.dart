import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/app_audio_player_controller.dart';
import '../models/audio_track.dart';
import '../services/user_service.dart';
import '../theme/clay_decorations.dart';

class AudioMiniPlayer extends StatefulWidget {
  const AudioMiniPlayer({
    super.key,
    this.controller,
    this.onTapPlayerDetails,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final AudioMiniPlayerController? controller;
  final VoidCallback? onTapPlayerDetails;
  final EdgeInsetsGeometry margin;

  @override
  State<AudioMiniPlayer> createState() => _AudioMiniPlayerState();
}

class _AudioMiniPlayerState extends State<AudioMiniPlayer> {
  late AudioMiniPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppAudioPlayerController.instance;
  }

  @override
  void didUpdateWidget(covariant AudioMiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller = widget.controller ?? AppAudioPlayerController.instance;
    }
  }

  void _openFullPlayer() {
    final detailsTap = widget.onTapPlayerDetails;
    if (detailsTap != null) {
      detailsTap();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return AudioFullPlayerSheet(controller: _controller);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppAudioPlayerState>(
      stream: _controller.stateStream,
      initialData: _controller.currentState,
      builder: (
        BuildContext context,
        AsyncSnapshot<AppAudioPlayerState> snapshot,
      ) {
        final state = snapshot.data ?? const AppAudioPlayerState.idle();
        final track = state.track;
        final visible = state.status != AppAudioPlaybackStatus.idle &&
            track != null &&
            _hasPlayableTrackSource(track);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: visible
              ? Padding(
                  key: ValueKey<String>('audio-mini-player-${track.id}'),
                  padding: widget.margin,
                  child: _AudioMiniPlayerCard(
                    state: state,
                    track: track,
                    controller: _controller,
                    onTapPlayerDetails: _openFullPlayer,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey<String>('hidden-player')),
        );
      },
    );
  }
}

bool _hasPlayableTrackSource(AudioTrack track) {
  return track.id.trim().isNotEmpty || track.audioUrl.trim().isNotEmpty;
}

class _AudioMiniPlayerCard extends StatelessWidget {
  const _AudioMiniPlayerCard({
    required this.state,
    required this.track,
    required this.controller,
    required this.onTapPlayerDetails,
  });

  final AppAudioPlayerState state;
  final AudioTrack track;
  final AudioMiniPlayerController controller;
  final VoidCallback onTapPlayerDetails;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(16));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius,
        boxShadow: clayShadows(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            borderRadius: radius,
          ),
              child: Stack(
                children: <Widget>[
                  InkWell(
                    onTap: onTapPlayerDetails,
                    splashColor: palette.accent.withValues(alpha: 0.07),
                    highlightColor: palette.accent.withValues(alpha: 0.035),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
                      child: Row(
                        children: <Widget>[
                          _AudioMiniThumbnail(track: track),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AudioMiniMarqueeText(track: track),
                          ),
                          const SizedBox(width: 4),
                          _MiniControlButton(
                            icon: Icons.skip_previous_rounded,
                            onPressed: controller.playPrevious,
                            palette: palette,
                          ),
                          _AudioMiniPlayPauseButton(
                            state: state,
                            track: track,
                            controller: controller,
                          ),
                          _MiniControlButton(
                            icon: Icons.skip_next_rounded,
                            onPressed: controller.playNext,
                            palette: palette,
                          ),
                          StreamBuilder<PlaybackMode>(
                            stream: controller.playbackModeStream,
                            initialData: controller.playbackMode,
                            builder: (
                              BuildContext ctx,
                              AsyncSnapshot<PlaybackMode> snap,
                            ) {
                              final mode =
                                  snap.data ?? PlaybackMode.none;
                              final IconData modeIcon;
                              final bool modeActive;
                              switch (mode) {
                                case PlaybackMode.loop:
                                  modeIcon = Icons.repeat_one_rounded;
                                  modeActive = true;
                                case PlaybackMode.shuffle:
                                  modeIcon = Icons.shuffle_rounded;
                                  modeActive = true;
                                case PlaybackMode.none:
                                  modeIcon = Icons.repeat_rounded;
                                  modeActive = false;
                              }
                              final nextMode = switch (mode) {
                                PlaybackMode.none => PlaybackMode.loop,
                                PlaybackMode.loop => PlaybackMode.shuffle,
                                PlaybackMode.shuffle => PlaybackMode.none,
                              };
                              return _MiniControlButton(
                                icon: modeIcon,
                                active: modeActive,
                                onPressed: () =>
                                    controller.setPlaybackMode(nextMode),
                                palette: palette,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _AudioMiniProgressBar(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

class _AudioMiniThumbnail extends StatelessWidget {
  const _AudioMiniThumbnail({required this.track});

  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);
    final thumbnailUrl = track.thumbnailUrl.trim();

    return SizedBox.square(
      dimension: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: thumbnailUrl.isEmpty
            ? _AudioMiniThumbnailFallback(color: palette.thumbnailFallback)
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _AudioMiniThumbnailFallback(
                    color: palette.thumbnailFallback),
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return _AudioMiniThumbnailFallback(
                    color: palette.thumbnailFallback,
                  );
                },
              ),
      ),
    );
  }
}

class _AudioMiniThumbnailFallback extends StatelessWidget {
  const _AudioMiniThumbnailFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

/// Scrolling marquee text that auto-advances when the track title overflows.
class _AudioMiniMarqueeText extends StatefulWidget {
  const _AudioMiniMarqueeText({required this.track});

  final AudioTrack track;

  @override
  State<_AudioMiniMarqueeText> createState() => _AudioMiniMarqueeTextState();
}

class _AudioMiniMarqueeTextState extends State<_AudioMiniMarqueeText> {
  final ScrollController _sc = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleScroll());
  }

  @override
  void didUpdateWidget(covariant _AudioMiniMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) {
      _timer?.cancel();
      if (_sc.hasClients) _sc.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleScroll());
    }
  }

  void _scheduleScroll() {
    if (!mounted || !_sc.hasClients) return;
    final max = _sc.position.maxScrollExtent;
    if (max <= 0) return; // text fits — no marquee needed

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _timer = Timer.periodic(const Duration(milliseconds: 35), (t) {
        if (!mounted || !_sc.hasClients) {
          t.cancel();
          return;
        }
        final pos = _sc.offset;
        final end = _sc.position.maxScrollExtent;
        if (pos >= end) {
          t.cancel();
          _sc.jumpTo(0);
          _scheduleScroll();
        } else {
          _sc.jumpTo(pos + 1.1);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          controller: _sc,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.track.title.trim().isEmpty
                ? 'Untitled track'
                : widget.track.title,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.track.channelTitle.trim().isEmpty
              ? 'Christian worship'
              : widget.track.channelTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.mutedText,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
        ),
      ],
    );
  }
}

/// Compact icon button used for Prev / Next / Loop-Shuffle in the mini player.
class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.icon,
    required this.onPressed,
    required this.palette,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final _AudioMiniPlayerPalette palette;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        splashColor: palette.accent.withValues(alpha: 0.12),
        child: Icon(
          icon,
          size: 18,
          color: active ? palette.accent : palette.mutedText,
        ),
      ),
    );
  }
}

class _AudioMiniPlayPauseButton extends StatelessWidget {
  const _AudioMiniPlayPauseButton({
    required this.state,
    required this.track,
    required this.controller,
  });

  final AppAudioPlayerState state;
  final AudioTrack track;
  final AudioMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    if (state.isLoading) {
      return SizedBox.square(
        dimension: 40,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.accent,
            ),
          ),
        ),
      );
    }

    final hasError = state.hasError;
    final icon = hasError
        ? Icons.replay_rounded
        : state.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;
    final tooltip = hasError
        ? 'Retry'
        : state.isPlaying
            ? 'Pause'
            : 'Play';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (state.isPlaying) {
              await controller.pause();
            } else if (hasError) {
              await controller.playTrack(track);
            } else {
              await controller.playTrack(track);
            }
          },
          borderRadius: BorderRadius.circular(999),
          splashColor: palette.accent.withValues(alpha: 0.1),
          highlightColor: palette.accent.withValues(alpha: 0.05),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.buttonBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: palette.accent, size: 24),
          ),
        ),
      ),
    );
  }
}

// ── Full player sheet ────────────────────────────────────────────────────────

class AudioFullPlayerSheet extends StatefulWidget {
  const AudioFullPlayerSheet({super.key, this.controller});

  final AudioMiniPlayerController? controller;

  @override
  State<AudioFullPlayerSheet> createState() => _AudioFullPlayerSheetState();
}

class _AudioFullPlayerSheetState extends State<AudioFullPlayerSheet> {
  late final AudioMiniPlayerController _controller;
  Timer? _sleepTimer;
  Timer? _sleepCountdown;
  Duration? _sleepRemaining;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AppAudioPlayerController.instance;
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    super.dispose();
  }

  void _showSleepTimerPicker() {
    final palette = _AudioMiniPlayerPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.playerSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sleep Timer',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (_sleepTimer != null)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel timer'),
                onTap: () { _cancelSleepTimer(); Navigator.pop(ctx); },
              ),
            for (final mins in <int>[15, 30, 60])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$mins minutes'),
                onTap: () { _setSleepTimer(Duration(minutes: mins)); Navigator.pop(ctx); },
              ),
            ListTile(
              leading: const Icon(Icons.skip_next_rounded),
              title: const Text('End of current song'),
              onTap: () { _setSleepAfterCurrentSong(); Navigator.pop(ctx); },
            ),
          ],
        ),
      ),
    );
  }

  void _setSleepTimer(Duration duration) {
    _cancelSleepTimer();
    setState(() { _sleepRemaining = duration; });
    _sleepTimer = Timer(duration, () async {
      await _controller.stop();
      if (mounted) _cancelSleepTimer();
    });
    _sleepCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = _sleepRemaining;
      if (r == null || r.inSeconds <= 0) { _cancelSleepTimer(); return; }
      setState(() { _sleepRemaining = r - const Duration(seconds: 1); });
    });
  }

  void _setSleepAfterCurrentSong() {
    _cancelSleepTimer();
    setState(() { _sleepRemaining = null; });
    _sleepTimer = Timer(const Duration(hours: 24), () {});
    _controller.stateStream
        .firstWhere((AppAudioPlayerState s) => s.status == AppAudioPlaybackStatus.completed)
        .then((_) async {
          await _controller.stop();
          if (mounted) _cancelSleepTimer();
        })
        .catchError((_) {});
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepCountdown = null;
    if (mounted) setState(() { _sleepRemaining = null; });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.playerSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
              bottom: Radius.circular(24),
            ),
            boxShadow: clayHeroShadows(Theme.of(context).brightness == Brightness.dark),
          ),
          child: StreamBuilder<AppAudioPlayerState>(
            stream: _controller.stateStream,
            initialData: _controller.currentState,
            builder: (BuildContext ctx, AsyncSnapshot<AppAudioPlayerState> snapshot) {
              final state = snapshot.data ?? const AppAudioPlayerState.idle();
              final track = state.track;
              if (track == null || !_hasPlayableTrackSource(track)) {
                return const SizedBox(height: 220);
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _FullPlayerHeader(controller: _controller, track: track),
                    const SizedBox(height: 18),
                    _FullPlayerArtwork(track: track),
                    const SizedBox(height: 22),
                    _FullPlayerTitleRow(track: track),
                    const SizedBox(height: 16),
                    _AudioFullProgress(controller: _controller),
                    // Status line (error / buffering)
                    _FullPlayerStatus(state: state),
                    const SizedBox(height: 4),
                    _FullPlayerControls(
                      state: state,
                      track: track,
                      controller: _controller,
                      sleepActive: _sleepTimer != null,
                      sleepRemaining: _sleepRemaining,
                      onSleepTap: _showSleepTimerPicker,
                    ),
                    const SizedBox(height: 14),
                    _FullPlayerActionBar(track: track, controller: _controller),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullPlayerHeader extends StatelessWidget {
  const _FullPlayerHeader({required this.controller, required this.track});
  final AudioMiniPlayerController controller;
  final AudioTrack track;

  void _showOptions(BuildContext context, _AudioMiniPlayerPalette palette) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.playerSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final url = 'https://www.youtube.com/watch?v=${track.id}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: palette.accent),
                title: const Text('Copy link'),
                onTap: () {
                  Navigator.pop(ctx);
                  // ignore: deprecated_member_use
                  // copy to clipboard
                  final data = ClipboardData(text: url);
                  Clipboard.setData(data);
                  showClaySnackBar(context, 'Link copied to clipboard', type: ClaySnackType.success);
                },
              ),
              ListTile(
                leading: Icon(Icons.share_rounded, color: palette.accent),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(ShareParams(text: '${track.title}\n$url'));
                },
              ),
              ListTile(
                leading: Icon(Icons.stop_rounded, color: palette.error),
                title: const Text('Stop playback'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await controller.stop();
                  if (context.mounted) Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);
    return Row(
      children: <Widget>[
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: palette.mutedText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'PLAYING FROM MUSIC',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.mutedText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Now Playing',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            tooltip: 'More options',
            icon: Icon(Icons.more_vert_rounded, color: palette.mutedText),
            onPressed: () => _showOptions(context, palette),
          ),
        ),
      ],
    );
  }
}

class _FullPlayerArtwork extends StatelessWidget {
  const _FullPlayerArtwork({required this.track});
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);
    final thumbnailUrl = track.thumbnailUrl.trim();
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        return SizedBox.square(
          dimension: constraints.maxWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: thumbnailUrl.isEmpty
                ? _AudioMiniThumbnailFallback(color: palette.thumbnailFallback)
                : Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) =>
                        _AudioMiniThumbnailFallback(color: palette.thumbnailFallback),
                  ),
          ),
        );
      },
    );
  }
}

class _FullPlayerTitleRow extends StatelessWidget {
  const _FullPlayerTitleRow({required this.track});
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    UserService? userService;
    try { userService = context.watch<UserService>(); } catch (_) {}

    final isFavorited = userService?.user.favoriteSongs.contains(track.id) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                track.title.trim().isEmpty ? 'Untitled track' : track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                track.channelTitle.trim().isEmpty ? 'Christian worship' : track.channelTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Favorite toggle
        if (userService != null)
          IconButton(
            tooltip: isFavorited ? 'Remove from favorites' : 'Add to favorites',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFavorited ? palette.accent : palette.mutedText,
              size: 26,
            ),
            onPressed: () {
              if (isFavorited) {
                userService!.removeFavoriteSong(track.id);
              } else {
                userService!.addFavoriteSong(track.id);
                if (!kIsWeb) {
                  AppAudioPlayerController.instance.downloadTrackForOffline(track);
                }
              }
            },
          ),
        // Download button — visible only when favorited (on mobile)
        if (isFavorited && !kIsWeb)
          IconButton(
            tooltip: 'Download for offline',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(Icons.download_rounded, color: palette.mutedText, size: 24),
            onPressed: () {
              AppAudioPlayerController.instance.downloadTrackForOffline(track);
              showClaySnackBar(context, 'Downloading for offline playback…');
            },
          ),
      ],
    );
  }
}

class _FullPlayerStatus extends StatelessWidget {
  const _FullPlayerStatus({required this.state});
  final AppAudioPlayerState state;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);
    final label = switch (state.status) {
      AppAudioPlaybackStatus.loading => 'Preparing audio…',
      AppAudioPlaybackStatus.buffering => 'Buffering…',
      AppAudioPlaybackStatus.completed => 'Finished',
      AppAudioPlaybackStatus.error => state.errorMessage?.trim().isNotEmpty == true
          ? state.errorMessage!.trim()
          : 'Unable to play this track.',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: state.hasError ? palette.error : palette.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AudioFullProgress extends StatelessWidget {
  const _AudioFullProgress({required this.controller});
  final AudioMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      initialData: Duration.zero,
      builder: (BuildContext context, AsyncSnapshot<Duration> positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: controller.durationStream,
          initialData: null,
          builder: (BuildContext context, AsyncSnapshot<Duration?> durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data;
            final durationMs = duration?.inMilliseconds ?? 0;
            final positionMs = durationMs > 0
                ? position.inMilliseconds.clamp(0, durationMs).toDouble()
                : 0.0;

            return Column(
              children: <Widget>[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: palette.accent,
                    inactiveTrackColor: palette.progressTrack,
                    thumbColor: palette.accent,
                    overlayColor: palette.accent.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    min: 0,
                    max: durationMs > 0 ? durationMs.toDouble() : 1,
                    value: positionMs,
                    onChanged: durationMs > 0
                        ? (double value) => controller.seek(Duration(milliseconds: value.round()))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(_formatDuration(position), style: Theme.of(context).textTheme.labelMedium),
                      Text(
                        duration == null ? '--:--' : _formatDuration(duration),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FullPlayerControls extends StatelessWidget {
  const _FullPlayerControls({
    required this.state,
    required this.track,
    required this.controller,
    required this.sleepActive,
    required this.sleepRemaining,
    required this.onSleepTap,
  });

  final AppAudioPlayerState state;
  final AudioTrack track;
  final AudioMiniPlayerController controller;
  final bool sleepActive;
  final Duration? sleepRemaining;
  final VoidCallback onSleepTap;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    return StreamBuilder<PlaybackMode>(
      stream: controller.playbackModeStream,
      initialData: controller.playbackMode,
      builder: (BuildContext ctx, AsyncSnapshot<PlaybackMode> snap) {
        final mode = snap.data ?? PlaybackMode.none;
        final isShuffle = mode == PlaybackMode.shuffle;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Shuffle
            _FullIconButton(
              icon: Icons.shuffle_rounded,
              active: isShuffle,
              palette: palette,
              onPressed: () => controller.setPlaybackMode(
                isShuffle ? PlaybackMode.none : PlaybackMode.shuffle,
              ),
            ),
            // Previous
            _FullIconButton(
              icon: Icons.skip_previous_rounded,
              size: 34,
              palette: palette,
              onPressed: controller.playPrevious,
            ),
            // Play / Pause
            _FullPlayPauseButton(state: state, track: track, controller: controller),
            // Next
            _FullIconButton(
              icon: Icons.skip_next_rounded,
              size: 34,
              palette: palette,
              onPressed: controller.playNext,
            ),
            // Sleep timer
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _FullIconButton(
                  icon: Icons.timer_outlined,
                  active: sleepActive,
                  palette: palette,
                  onPressed: onSleepTap,
                ),
                if (sleepRemaining != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDuration(sleepRemaining!),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FullPlayPauseButton extends StatelessWidget {
  const _FullPlayPauseButton({
    required this.state,
    required this.track,
    required this.controller,
  });

  final AppAudioPlayerState state;
  final AudioTrack track;
  final AudioMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);
    final isBusy = state.isLoading;
    final icon = state.hasError
        ? Icons.replay_rounded
        : state.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy
            ? null
            : () async {
                if (state.isPlaying) {
                  await controller.pause();
                } else if (state.isPaused) {
                  await controller.resume();
                } else {
                  await controller.playTrack(track);
                }
              },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 68,
          height: 68,
          decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
          child: Center(
            child: isBusy
                ? const SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.8, color: Colors.white),
                  )
                : Icon(icon, color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }
}

class _FullIconButton extends StatelessWidget {
  const _FullIconButton({
    required this.icon,
    required this.palette,
    required this.onPressed,
    this.size = 26.0,
    this.active = false,
  });

  final IconData icon;
  final _AudioMiniPlayerPalette palette;
  final VoidCallback? onPressed;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Icon(icon, size: size, color: active ? palette.accent : palette.mutedText),
      ),
    );
  }
}

class _FullPlayerActionBar extends StatelessWidget {
  const _FullPlayerActionBar({required this.track, required this.controller});
  final AudioTrack track;
  final AudioMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          tooltip: 'Share',
          icon: Icon(Icons.share_rounded, color: palette.mutedText),
          onPressed: () {
            final url = 'https://www.youtube.com/watch?v=${track.id}';
            SharePlus.instance.share(
              ShareParams(text: '${track.title}\n$url'),
            );
          },
        ),
        IconButton(
          tooltip: 'Queue',
          icon: Icon(Icons.queue_music_rounded, color: palette.mutedText),
          onPressed: () => _showQueue(context, palette),
        ),
        IconButton(
          tooltip: 'Stop',
          icon: Icon(Icons.stop_circle_outlined, color: palette.mutedText),
          onPressed: () async {
            final nav = Navigator.of(context);
            await controller.stop();
            nav.maybePop();
          },
        ),
      ],
    );
  }

  void _showQueue(BuildContext context, _AudioMiniPlayerPalette palette) {
    final ctrl = controller;
    if (ctrl is! AppAudioPlayerController || !ctrl.hasQueue) {
      showClaySnackBar(context, 'No tracks in queue.', type: ClaySnackType.info);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.playerSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _QueueSheet(controller: ctrl, palette: palette),
    );
  }
}

class _QueueSheet extends StatefulWidget {
  const _QueueSheet({required this.controller, required this.palette});
  final AppAudioPlayerController controller;
  final _AudioMiniPlayerPalette palette;

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  @override
  Widget build(BuildContext context) {
    final tracks = widget.controller.queue;
    final currentIndex = widget.controller.currentQueueIndex;
    final palette = widget.palette;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.mutedText.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Up Next',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${tracks.length} tracks',
                    style: TextStyle(color: palette.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: tracks.length,
                itemBuilder: (ctx, index) {
                  final track = tracks[index];
                  final isPlaying = index == currentIndex;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: track.thumbnailUrl.trim().isNotEmpty
                          ? Image.network(
                              track.thumbnailUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _QueueTrackPlaceholder(palette: palette),
                            )
                          : _QueueTrackPlaceholder(palette: palette),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying
                            ? palette.accent
                            : Theme.of(ctx).colorScheme.onSurface,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      track.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.mutedText, fontSize: 12),
                    ),
                    trailing: isPlaying
                        ? Icon(Icons.equalizer_rounded, color: palette.accent, size: 20)
                        : null,
                    onTap: () {
                      widget.controller.playTrack(track);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueTrackPlaceholder extends StatelessWidget {
  const _QueueTrackPlaceholder({required this.palette});
  final _AudioMiniPlayerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: palette.mutedText.withValues(alpha: 0.15),
      child: Icon(Icons.music_note_rounded, color: palette.mutedText, size: 20),
    );
  }
}

class _AudioMiniProgressBar extends StatelessWidget {
  const _AudioMiniProgressBar({required this.controller});

  final AudioMiniPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      initialData: Duration.zero,
      builder: (
        BuildContext context,
        AsyncSnapshot<Duration> positionSnapshot,
      ) {
        return StreamBuilder<Duration?>(
          stream: controller.durationStream,
          initialData: null,
          builder: (
            BuildContext context,
            AsyncSnapshot<Duration?> durationSnapshot,
          ) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data;
            final progress = _progressFraction(position, duration);

            return _AudioMiniProgressValue(value: progress);
          },
        );
      },
    );
  }

  double _progressFraction(Duration position, Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) {
      return 0;
    }

    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class _AudioMiniProgressValue extends StatelessWidget {
  const _AudioMiniProgressValue({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = _AudioMiniPlayerPalette.of(context);

    return SizedBox(
      height: 2.5,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: palette.progressTrack),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: DecoratedBox(
              decoration: BoxDecoration(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioMiniPlayerPalette {
  const _AudioMiniPlayerPalette({
    required this.surface,
    required this.playerSurface,
    required this.border,
    required this.shadow,
    required this.accent,
    required this.error,
    required this.mutedText,
    required this.buttonBackground,
    required this.progressTrack,
    required this.thumbnailFallback,
  });

  final Color surface;
  final Color playerSurface;
  final Color border;
  final Color shadow;
  final Color accent;
  final Color error;
  final Color mutedText;
  final Color buttonBackground;
  final Color progressTrack;
  final Color thumbnailFallback;

  static _AudioMiniPlayerPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _AudioMiniPlayerPalette(
        surface: Color(0xFF1A231F),
        playerSurface: Color(0xFF18211D),
        border: Color(0x66394A43),
        shadow: Color(0x52000000),
        accent: Color(0xFF8FD8B5),
        error: Color(0xFFFFB4AB),
        mutedText: Color(0xFFAAB7B0),
        buttonBackground: Color(0xFF22312A),
        progressTrack: Color(0x332E3D36),
        thumbnailFallback: Color(0xFF2D6A58),
      );
    }

    return const _AudioMiniPlayerPalette(
      surface: Color(0xFFFFFCF7),
      playerSurface: Color(0xFFFFFCF7),
      border: Color(0xCCE4D8C5),
      shadow: Color(0x1F000000),
      accent: Color(0xFF185642),
      error: Color(0xFFBA1A1A),
      mutedText: Color(0xFF6C6A65),
      buttonBackground: Color(0xFFE4F1EA),
      progressTrack: Color(0x55E6DAC8),
      thumbnailFallback: Color(0xFF28745E),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
