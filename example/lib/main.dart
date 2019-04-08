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
    // source: "http://10.42.0.1/video.mp4", // this is my personal local server link when i don't have internet. u can ignore this.
    desc: "Note from Apple",
  );

  @override
  void initState() {
    // first argument for isBackground next for showNotification.
    player =
        MediaPlayerPlugin.create(isBackground: true, showNotification: true);
    initVideo();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();

    print("dispose called");
    player.dispose();
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
        padding: EdgeInsets.symmetric(vertical: 5.0),
      ),
      SizedBox(height: 20.0),
      buildButtons()
    ]);
  }

  Widget buildButtons() {
    return Wrap(
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
        FlatButton(
          child: Text("stop"),
          onPressed: () {
            player.dispose();
          },
        ),
      ],
    );
  }
}
