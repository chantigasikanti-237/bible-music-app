import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/saved_verse_record.dart';
import '../../models/user_model.dart';
import '../../services/verse_service.dart';
import '../../services/user_service.dart';
import '../../widgets/adaptive_layout.dart';
import '../../theme/clay_decorations.dart';

class BookmarkedVersesPage extends StatefulWidget {
  const BookmarkedVersesPage({super.key});

  @override
  State<BookmarkedVersesPage> createState() => _BookmarkedVersesPageState();
}

class _BookmarkedVersesPageState extends State<BookmarkedVersesPage> {
  static const String _allCollectionId = '__all__';
  static const String _unsortedCollectionId = '__unsorted__';

  final VerseService _verseService = VerseService();
  String _selectedCollectionId = _allCollectionId;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserService>(
      builder: (
        BuildContext context,
        UserService userService,
        _,
      ) {
        final user = userService.user;
        final collectionSummaries = _buildCollections(user);
        _syncSelectedCollection(collectionSummaries);
        final visibleVerses = _filterVerses(user);
        final collectionWidgets = <Widget>[
          Text(
            'Saved collections',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Organize the verses you save from the reader into custom folders.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B655E),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: collectionSummaries.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                if (index == collectionSummaries.length) {
                  return _CreateCollectionCard(
                    onTap: _promptCreateCollection,
                  );
                }

                final collection = collectionSummaries[index];
                return _CollectionCard(
                  title: collection.title,
                  subtitle: collection.subtitle,
                  count: collection.count,
                  icon: collection.icon,
                  selected: collection.id == _selectedCollectionId,
                  onTap: () {
                    setState(() {
                      _selectedCollectionId = collection.id;
                    });
                  },
                );
              },
            ),
          ),
        ];

        final verseWidgets = <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _selectedCollectionLabel(collectionSummaries),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: _promptCreateCollection,
                icon: const Icon(Icons.create_new_folder_rounded),
                label: const Text('New folder'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleVerses.isEmpty)
            _EmptyBookmarkState(
              showCreateFolder: user.bookmarkCollections.isEmpty,
              onCreateFolder: _promptCreateCollection,
            )
          else
            ...visibleVerses.map(
              (SavedVerseRecord verse) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SavedVerseCard(
                  verse: verse,
                  folderName: _folderNameForVerse(
                    verse,
                    user.bookmarkCollections,
                  ),
                  onMove: () => _showMoveSheet(verse),
                  onDelete: () => _deleteVerse(
                    verse,
                    userService: userService,
                    authStatus: user.authStatus,
                  ),
                ),
              ),
            ),
        ];
        final collectionsPane = ListView(children: collectionWidgets);
        final versesPane = ListView(children: verseWidgets);

        return AdaptiveScaffold(
          backgroundColor: const Color(0xFFF6F1E7),
          appBar: AppBar(
            title: const Text('Bookmarked Verses'),
          ),
          bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
            if (!layout.useTwoPane) {
              return Padding(
                padding: layout.pagePadding,
                child: ListView(
                  children: <Widget>[
                    ...collectionWidgets,
                    const SizedBox(height: 22),
                    ...verseWidgets,
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
                    child: collectionsPane,
                  ),
                  SizedBox(width: layout.paneSpacing),
                  Expanded(
                    flex: layout.splitPrimaryFlex,
                    child: versesPane,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<_CollectionSummary> _buildCollections(UserModel user) {
    final unsortedCount = user.savedVerses
        .where((SavedVerseRecord verse) => verse.collectionId == null)
        .length;
    return <_CollectionSummary>[
      _CollectionSummary(
        id: _allCollectionId,
        title: 'All',
        subtitle: 'All saved verses',
        count: user.savedVerses.length,
        icon: Icons.bookmarks_rounded,
      ),
      _CollectionSummary(
        id: _unsortedCollectionId,
        title: 'Unsorted',
        subtitle: 'Ready to organize',
        count: unsortedCount,
        icon: Icons.inventory_2_rounded,
      ),
      ...user.bookmarkCollections.map(
        (BookmarkCollection collection) => _CollectionSummary(
          id: collection.id,
          title: collection.name,
          subtitle: '${_countVersesInCollection(user, collection.id)} saved',
          count: _countVersesInCollection(user, collection.id),
          icon: Icons.folder_rounded,
        ),
      ),
    ];
  }

  int _countVersesInCollection(UserModel user, String collectionId) {
    return user.savedVerses
        .where((SavedVerseRecord verse) => verse.collectionId == collectionId)
        .length;
  }

  List<SavedVerseRecord> _filterVerses(UserModel user) {
    switch (_selectedCollectionId) {
      case _unsortedCollectionId:
        return user.savedVerses
            .where((SavedVerseRecord verse) => verse.collectionId == null)
            .toList(growable: false);
      case _allCollectionId:
        return user.savedVerses;
      default:
        return user.savedVerses
            .where(
              (SavedVerseRecord verse) =>
                  verse.collectionId == _selectedCollectionId,
            )
            .toList(growable: false);
    }
  }

  void _syncSelectedCollection(List<_CollectionSummary> collections) {
    if (collections.any(
      (_CollectionSummary collection) => collection.id == _selectedCollectionId,
    )) {
      return;
    }
    _selectedCollectionId = _allCollectionId;
  }

  String _selectedCollectionLabel(List<_CollectionSummary> collections) {
    final selected = collections.cast<_CollectionSummary?>().firstWhere(
          (_CollectionSummary? collection) =>
              collection?.id == _selectedCollectionId,
          orElse: () => null,
        );
    return selected?.title ?? 'All';
  }

  String? _folderNameForVerse(
    SavedVerseRecord verse,
    List<BookmarkCollection> collections,
  ) {
    final collectionId = verse.collectionId;
    if (collectionId == null) {
      return null;
    }
    final folder = collections.cast<BookmarkCollection?>().firstWhere(
          (BookmarkCollection? collection) => collection?.id == collectionId,
          orElse: () => null,
        );
    return folder?.name;
  }

  Future<void> _promptCreateCollection({SavedVerseRecord? assignVerse}) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Peace, Strength, Faith...',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    final normalizedName = name?.trim() ?? '';
    if (normalizedName.isEmpty) {
      return;
    }

    try {
      final collection =
          context.read<UserService>().createBookmarkCollection(normalizedName);
      if (assignVerse != null) {
        context.read<UserService>().assignSavedVerseToCollection(
              assignVerse.id,
              collection.id,
            );
        setState(() {
          _selectedCollectionId = collection.id;
        });
      }
    } on ArgumentError catch (error) {
      showClaySnackBar(context, error.message.toString(), type: ClaySnackType.error);
    }
  }

  Future<void> _showMoveSheet(SavedVerseRecord verse) async {
    final user = context.read<UserService>().user;
    final collections = user.bookmarkCollections;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (BuildContext context) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Move to folder',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verse.reference,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6D675F),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _MoveFolderTile(
                    icon: Icons.remove_circle_outline_rounded,
                    title: 'Unsorted',
                    selected: verse.collectionId == null,
                    onTap: () {
                      context.read<UserService>().assignSavedVerseToCollection(
                            verse.id,
                            null,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final BookmarkCollection collection in collections)
                    _MoveFolderTile(
                      icon: Icons.folder_rounded,
                      title: collection.name,
                      selected: verse.collectionId == collection.id,
                      onTap: () {
                        context
                            .read<UserService>()
                            .assignSavedVerseToCollection(
                              verse.id,
                              collection.id,
                            );
                        setState(() {
                          _selectedCollectionId = collection.id;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _promptCreateCollection(assignVerse: verse);
                    },
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: const Text('Create folder'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteVerse(
    SavedVerseRecord verse, {
    required UserService userService,
    required AuthStatus authStatus,
  }) async {
    userService.removeSavedVerse(verse.id);

    if (authStatus == AuthStatus.loggedIn &&
        verse.remoteId != null &&
        verse.remoteId!.isNotEmpty) {
      try {
        await _verseService.deleteSavedVerse(verse.remoteId!);
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }
    showClaySnackBar(context, 'Bookmark removed', type: ClaySnackType.info);
  }
}

class _CollectionSummary {
  const _CollectionSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 162,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? const <Color>[
                        Color(0xFFE6F1EB),
                        Color(0xFFD7E6DD),
                      ]
                    : const <Color>[
                        Color(0xFFFFFCF7),
                        Color(0xFFF2EBDD),
                      ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: claySmallShadows(Theme.of(context).brightness == Brightness.dark,
                  shadowHue: selected ? const Color(0xFF176651) : const Color(0xFF1A5A47)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF176651)
                        : const Color(0xFFE5EFE9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : const Color(0xFF195241),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B655E),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF184B3C),
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

class _CreateCollectionCard extends StatelessWidget {
  const _CreateCollectionCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(28),
              boxShadow: claySmallShadows(Theme.of(context).brightness == Brightness.dark),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EFE9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF195241),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'New Folder',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedVerseCard extends StatelessWidget {
  const _SavedVerseCard({
    required this.verse,
    required this.folderName,
    required this.onMove,
    required this.onDelete,
  });

  final SavedVerseRecord verse;
  final String? folderName;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
        boxShadow: clayShadows(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        verse.reference,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        verse.versionLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6E675F),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (String value) {
                    if (value == 'move') {
                      onMove();
                      return;
                    }
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'move',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.drive_file_move_rounded),
                          SizedBox(width: 10),
                          Text('Move to folder'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.delete_rounded),
                          SizedBox(width: 10),
                          Text('Remove bookmark'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              verse.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.7,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  icon: Icons.menu_book_rounded,
                  label: verse.languageCode.toUpperCase(),
                ),
                _InfoPill(
                  icon: Icons.bookmark_rounded,
                  label: folderName ?? 'Unsorted',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveFolderTile extends StatelessWidget {
  const _MoveFolderTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFFE3F0E8) : const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(20),
              boxShadow: claySmallShadows(Theme.of(context).brightness == Brightness.dark,
                  shadowHue: selected ? const Color(0xFF176651) : const Color(0xFF1A5A47)),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: const Color(0xFF185040)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF17624D),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFEA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFF16513F)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF16513F),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBookmarkState extends StatelessWidget {
  const _EmptyBookmarkState({
    required this.showCreateFolder,
    required this.onCreateFolder,
  });

  final bool showCreateFolder;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFCF7),
            Color(0xFFF2EBDE),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: clayShadows(Theme.of(context).brightness == Brightness.dark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F0EA),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: Color(0xFF17513F),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No bookmarked verses yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Long-press a verse in the reader and tap Bookmark to save it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B655E),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
            ),
            if (showCreateFolder) ...<Widget>[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onCreateFolder,
                icon: const Icon(Icons.create_new_folder_rounded),
                label: const Text('Create first folder'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
