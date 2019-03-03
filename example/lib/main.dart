import 'package:flutter/material.dart';
import 'package:media_player/data_sources.dart';
import 'package:media_player/media_player.dart';
import 'package:media_player/ui.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: MyVideoScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyVideoScreen extends StatefulWidget {
  @override
  _MyVideoScreenState createState() => _MyVideoScreenState();
}

class _MyVideoScreenState extends State<MyVideoScreen> {
  MediaPlayer player;
  MediaFile song1 = MediaFile(
    title: "Despacito 1",
    type: "video",
    source:
        "https://firebasestorage.googleapis.com/v0/b/mziki-d37f5.appspot.com/o/---Rj%20Kanierra%20Brassard%20Clip%20Officiel%20by%20King%20Inter10ment%20-%20YouTube.mp3?alt=media&token=1b8f96f4-670c-4a10-b616-7f7d6fb0e3b8",
    desc: "Lorem  ipsum desit.",
  );
  // MediaFile song2 = MediaFile(
  //   title: "Apple Keynote 2",
  //   type: "video",
  //   source: "http://qthttp.apple.com.edgesuite.net/1010qwoeiuryfg/sl.m3u8",
  //   desc: "Lorem  ipsum desit.",
  // );
  // MediaFile song3 = MediaFile(
  //   title: "Some m3u8 test",
  //   type: "audio",
  //   source: "https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8",
  //   desc: "Lorem  ipsum desit.",
  // );

  bool next = false;
  bool prev = false;
  var source;
  int currentIndex = 0;
  @override
  void initState() {
    // first argument for isBackground next for showNotification.
    player =
        MediaPlayerPlugin.create(isBackground: true, showNotification: true);
    initVideo();
    player.valueNotifier.addListener(() {
      if (!mounted) return;
      next = player.valueNotifier.value.next;
      prev = player.valueNotifier.value.prev;
      source = player.valueNotifier.value.source;
      currentIndex = player.valueNotifier.value.currentIndex;
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void initVideo() async {
    // Playlist playlist = Playlist([song1, song2, song3]);
    await player.initialize();
    player.setSource(playlist);
    player.setSource(song1);
    // await player.setPlaylist(playlist);
    player.play();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      VideoPlayerView(player),
      VideoProgressIndicator(
        player,
        allowScrubbing: true,
        padding: EdgeInsets.symmetric(vertical: 5.0),
      ),
      SizedBox(height: 20.0),
      // source != null
      //     ? Container(
      //         child: Text(source.contents[currentIndex].title),
      //       )
      //     : Container(),
      buildButtons(),
      // Expanded(child: _playlist())
    ]);
  }

  // Widget _playlist() {
  //   return (source is Playlist)
  //       ? ListView.builder(
  //           itemCount: source.count,
  //           itemBuilder: (BuildContext context, index) {
  //             return ListTile(
  //                 title: Text(source.contents[index].title),
  //                 trailing: IconButton(
  //                   onPressed: () {
  //                     player.playAt(index);
  //                   },
  //                   icon: Icon((currentIndex == index)
  //                       ? Icons.pause
  //                       : Icons.play_arrow),
  //                 ));
  //           },
  //         )
  //       : Container();
  // }

  Row buildButtons() {
    return Row(
      children: <Widget>[
        FlatButton(
          child: Text("Prev"),
          onPressed: (prev)
              ? () {
                  player.playPrev();
                }
              : null,
        ),
        FlatButton(
          child: Text("Play"),
          onPressed: () {
            player.play();
          },
        ),
        FlatButton(
          child: Text("Pause"),
          onPressed: () {
            player.pause();
          },
        ),
        FlatButton(
          child: Text("Next"),
          onPressed: next
              ? () {
                  player.playNext();
                }
              : null,
        ),
      ],
    );
  }
}
