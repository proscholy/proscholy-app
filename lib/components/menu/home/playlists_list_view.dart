import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zpevnik/components/highlightable.dart';
import 'package:zpevnik/components/icon_item.dart';
import 'package:zpevnik/components/playlist/dialogs.dart';
import 'package:zpevnik/components/playlist/playlist_row.dart';
import 'package:zpevnik/constants.dart';
import 'package:zpevnik/providers/data.dart';

class PlaylistsListView extends StatelessWidget {
  const PlaylistsListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final playlists = [dataProvider.favorites] + dataProvider.playlists;

    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.only(top: kDefaultPadding / 2, bottom: 2 * kDefaultPadding),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: playlists.length + 1,
      itemBuilder: (_, index) {
        if (index == playlists.length) {
          return Highlightable(
            onTap: () => showPlaylistDialog(context),
            padding: const EdgeInsets.all(kDefaultPadding),
            child: const IconItem(icon: Icons.add, text: 'Vytvořit nový seznam', iconSize: 20),
          );
        }

        return PlaylistRow(playlist: playlists[index], visualDensity: VisualDensity.comfortable);
      },
    );
  }
}
