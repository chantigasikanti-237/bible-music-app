import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/music_service.dart';
import 'package:provider/provider.dart';
import '../../widgets/adaptive_layout.dart';
import '../../theme/clay_decorations.dart';

class FavoriteMusicPage extends StatefulWidget {
  const FavoriteMusicPage({super.key});

  @override
  State<FavoriteMusicPage> createState() => _FavoriteMusicPageState();
}

class _FavoriteMusicPageState extends State<FavoriteMusicPage> {
  final MusicService _songsService = MusicService();
  List<Map<String, dynamic>> _songsData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongsData();
  }

  Future<void> _loadSongsData() async {
    final songs = await _songsService.loadSongs();
    if (!mounted) return;
    setState(() {
      _songsData = songs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userService = Provider.of<UserService>(context, listen: false);
    final user = userService.user;
    final favorites = user.favoriteSongs;
    final summaryCard = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFCF7),
            Color(0xFFF1EADF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: clayHeroShadows(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Favorite music',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your most-played music close at hand. Landscape shows this summary beside the list so nothing gets cramped.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B655E),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '${favorites.length}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: const Color(0xFF184B3C),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'saved favorites',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF5F675F),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );

    final listPane = _loading
        ? clayLoadingCenter(context)
        : favorites.isEmpty
            ? const Center(child: Text('No favorite music yet.'))
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: clayShadows(Theme.of(context).brightness == Brightness.dark),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final songId = favorites[i];
                    final details = _getSongDetails(songId);
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: const Color(0xFFFBF6ED),
                      title: Text(details['title'] ?? 'Song $songId'),
                      subtitle: details['artist'] != null
                          ? Text(details['artist']!)
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          userService.removeFavoriteSong(songId);
                          showClaySnackBar(
                            context,
                            'Favorite removed',
                            type: ClaySnackType.info,
                            action: SnackBarAction(
                              label: 'UNDO',
                              textColor: const Color(0xFF8FD8B5),
                              onPressed: () {
                                userService.addFavoriteSong(songId);
                              },
                            ),
                          );
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
              );

    return AdaptiveScaffold(
      backgroundColor: const Color(0xFFF6F1E7),
      appBar: AppBar(title: const Text('Favorite Music')),
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        if (!layout.useTwoPane) {
          return Padding(
            padding: layout.pagePadding,
            child: Column(
              children: <Widget>[
                summaryCard,
                const SizedBox(height: 16),
                Expanded(child: listPane),
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
                child: summaryCard,
              ),
              SizedBox(width: layout.paneSpacing),
              Expanded(
                flex: layout.splitPrimaryFlex,
                child: listPane,
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, String?> _getSongDetails(String songId) {
    Map<String, dynamic>? song;
    for (final item in _songsData) {
      if (item['id'].toString() == songId) {
        song = item;
        break;
      }
    }
    if (song == null) return {'title': null, 'artist': null};
    return {
      'title': song['title']?.toString(),
      'artist': song['artist']?.toString(),
    };
  }
}
