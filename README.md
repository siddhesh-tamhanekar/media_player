# media_player(android support only)

This media player uses an google Exoplayer in android to play the media files.

**Note:  the media player is inspired and developer by google plugin video_player and uses most code of it  and added  extra features.**


If you don't want to bother with implementing ui widgets and need a readymade video player 
you can visit  http://flutter-media-player.cf 

##  Features

* Can play Audio and Video File URLs (mp3, mp4, m3u8 etc) 
* Playlist Support
* Single Media File Play Support
* Control over player (play, pause, next, prev, seek etc.)
* can be used to create background player(mostly used for audio playing).
* Persistent Notification


##  Screenshots

![some of the screenhosts](https://raw.githubusercontent.com/siddhesh-tamhanekar/siddhesh-tamhanekar.github.io/master/images/screenshots/sc1.png ) 

![some of the screenhosts](https://raw.githubusercontent.com/siddhesh-tamhanekar/siddhesh-tamhanekar.github.io/master/images/screenshots/sc2.png )

![some of the screenhosts](https://raw.githubusercontent.com/siddhesh-tamhanekar/siddhesh-tamhanekar.github.io/master/images/screenshots/sc3.png ) 

![some of the screenhosts](https://raw.githubusercontent.com/siddhesh-tamhanekar/siddhesh-tamhanekar.github.io/master/images/screenshots/sc5.png )

  

## Getting Started

#### STEP 1: add dependancy into pubspec.yaml file


#### STEP 2: Add following code into AndroidManifest.xml

**Add service  android/app/AndroidManifest.xml**
```
<service
    android:name="com.example.mediaplayer.AudioService"
    android:enabled="true"
    android:exported="false">
</service>
```

**Add the permission for foreground service in same AndroidManifest.xml .**
 ```
 <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
 ```
---

#### STEP 3: Add the following dependency into android/app/build.graddle
```
    android {
            compileOptions {
                sourceCompatibility JavaVersion.VERSION_1_8
                targetCompatibility JavaVersion.VERSION_1_8
            }
    }
```

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
  VideoPlayer player;
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