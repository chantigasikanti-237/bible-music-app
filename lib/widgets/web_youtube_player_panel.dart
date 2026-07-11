import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../controllers/app_audio_player_controller.dart';
import '../controllers/web_youtube_player_controller.dart';
import '../models/audio_track.dart';

/// Persistent bottom panel that hosts the YouTube IFrame player on web.
///
/// The [YoutubePlayer] widget (and its underlying IFrame element) stays in the
/// widget tree as long as a track is active, so audio continues even when the
/// panel is collapsed to its mini-bar state. Removing the widget from the tree
/// would destroy the IFrame and stop playback.
///
/// Replaces [AudioMiniPlayer] on web — see main.dart for the platform branch.
class WebYouTubePlayerPanel extends StatefulWidget {
  const WebYouTubePlayerPanel({super.key});

  @override
  State<WebYouTubePlayerPanel> createState() => _WebYouTubePlayerPanelState();
}

class _WebYouTubePlayerPanelState extends State<WebYouTubePlayerPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppAudioPlayerState>(
      stream: WebYouTubePlayerController.instance.stateStream,
      initialData: WebYouTubePlayerController.instance.currentState,
      builder: (
        BuildContext context,
        AsyncSnapshot<AppAudioPlayerState> snapshot,
      ) {
        final state = snapshot.data ?? const AppAudioPlayerState.idle();

        if (state.status == AppAudioPlaybackStatus.idle || state.track == null) {
          if (_expanded) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => setState(() => _expanded = false));
          }
          return const SizedBox.shrink();
        }

        final track = state.track!;
        final palette = _WebPlayerPalette.of(context);

        // Width-based video height so the 16:9 IFrame fills the panel exactly.
        final videoHeight =
            MediaQuery.of(context).size.width * 9.0 / 16.0;

        return Material(
          color: palette.surface,
          elevation: 12,
          shadowColor: Colors.black38,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // ── IFrame ─────────────────────────────────────────────────────
              // AnimatedContainer smoothly resizes between 0 (collapsed) and
              // full video height (expanded). Keeping the SizedBox at height=0
              // rather than using Offstage preserves the IFrame in the DOM so
              // audio is not interrupted when the panel is collapsed.
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                height: _expanded ? videoHeight : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: YoutubePlayer(
                  controller: WebYouTubePlayerController.instance.ytController,
                  aspectRatio: 16 / 9,
                  enableFullScreenOnVerticalDrag: false,
                ),
              ),
              // ── Mini bar ───────────────────────────────────────────────────
              _MiniBar(
                track: track,
                state: state,
                expanded: _expanded,
                palette: palette,
                onToggleExpand: () =>
                    setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Mini bar ──────────────────────────────────────────────────────────────────

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.track,
    required this.state,
    required this.expanded,
    required this.palette,
    required this.onToggleExpand,
  });

  final AudioTrack track;
  final AppAudioPlayerState state;
  final bool expanded;
  final _WebPlayerPalette palette;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = track.thumbnailUrl.trim();

    return SizedBox(
      height: 68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 44,
                  child: thumbnailUrl.isEmpty
                      ? _ThumbnailFallback(color: palette.accent)
                      : Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ThumbnailFallback(color: palette.accent),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      track.title.trim().isEmpty
                          ? 'Untitled track'
                          : track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.channelTitle.trim().isEmpty
                          ? 'Christian worship'
                          : track.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              // Play / pause
              _PlayPauseButton(state: state, palette: palette),
              // Stop
              IconButton(
                tooltip: 'Stop',
                icon: Icon(Icons.stop_rounded, color: palette.mutedText),
                onPressed: () =>
                    WebYouTubePlayerController.instance.stop(),
              ),
              // Expand / collapse
              IconButton(
                tooltip: expanded ? 'Collapse player' : 'Expand player',
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: palette.accent,
                ),
                onPressed: onToggleExpand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.state, required this.palette});

  final AppAudioPlayerState state;
  final _WebPlayerPalette palette;

  @override
  Widget build(BuildContext context) {
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final ctrl = WebYouTubePlayerController.instance;
          if (state.isPlaying) {
            await ctrl.pause();
          } else {
            await ctrl.resume();
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: palette.buttonBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(
            state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: palette.accent,
            size: 22,
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
      color: color.withValues(alpha: 0.18),
      child: Icon(Icons.music_note_rounded, color: color, size: 20),
    );
  }
}

// ── Palette ───────────────────────────────────────────────────────────────────

class _WebPlayerPalette {
  const _WebPlayerPalette({
    required this.surface,
    required this.border,
    required this.accent,
    required this.mutedText,
    required this.buttonBackground,
  });

  final Color surface;
  final Color border;
  final Color accent;
  final Color mutedText;
  final Color buttonBackground;

  static _WebPlayerPalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _WebPlayerPalette(
        surface: Color(0xFF18211D),
        border: Color(0xFF2E3D36),
        accent: Color(0xFF8FD8B5),
        mutedText: Color(0xFFAAB7B0),
        buttonBackground: Color(0xFF22312A),
      );
    }
    return const _WebPlayerPalette(
      surface: Color(0xFFFFFCF7),
      border: Color(0xFFE4D8C5),
      accent: Color(0xFF185642),
      mutedText: Color(0xFF6C6A65),
      buttonBackground: Color(0xFFE4F1EA),
    );
  }
}
