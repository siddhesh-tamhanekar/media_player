# media_player_example

Demonstrates how to use the media_player plugin.


If you don't want to bother with implementing ui widgets and need a readymade video player UI,
visit the http://flutter-media-player.cf 

## Simple Example

```
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
    title: "Song 1",
    type: "video",
    source: "http://qthttp.apple.com.edgesuite.net/1010qwoeiuryfg/sl.m3u8",
    desc: "Note from Apple",
  );

  @override
  void initState() {
    // first argument for isBackground next for showNotification.
    player = MediaPlayerPlugin.create(isBackground: true, showNotification: true);
    initVideo();
    super.initState();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void initVideo() async {
    await player.initialize();
    await player.setSource(song1);
    player.play();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      VideoPlayerView(player),
      VideoProgressIndicator(
        player,
        allowScrubbing: true,
         padding: EdgeInsets.symmetric(vertical:5.0),
      ),
      SizedBox(height:20.0),
      buildButtons()
    ]);
  }

  Row buildButtons() {
    return Row(
      children: <Widget>[
        FlatButton(
          child: Text("Prev"),
          onPressed: () {
            player.playPrev();
          },
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
          onPressed: () {
            player.playNext();
          },
        ),
      ],
    );
  }
}


```
