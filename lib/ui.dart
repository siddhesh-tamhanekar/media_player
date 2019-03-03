import 'package:flutter/material.dart';
import 'package:media_player/media_player.dart';

class VideoProgressColors {
  VideoProgressColors({
    this.playedColor = const Color.fromRGBO(255, 0, 0, 0.7),
    this.bufferedColor = const Color.fromRGBO(50, 50, 200, 0.2),
    this.backgroundColor = const Color.fromRGBO(200, 200, 200, 0.5),
  });

  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;
}

class _VideoScrubber extends StatefulWidget {
  _VideoScrubber({
    @required this.child,
    @required this.controller,
  });

  final Widget child;
  final MediaPlayer controller;

  @override
  _VideoScrubberState createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<_VideoScrubber> {
  bool _controllerWasPlaying = false;

  MediaPlayer get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    void seekToRelativePosition(Offset globalPosition) {
      final RenderBox box = context.findRenderObject();
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      final Duration position =
          controller.valueNotifier.value.duration * relative;
      controller.seek(position.inMilliseconds);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: widget.child,
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.valueNotifier.value.initialized) {
          return;
        }
        _controllerWasPlaying = controller.valueNotifier.value.isPlaying;
        if (_controllerWasPlaying) {
          controller.pause();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller.valueNotifier.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_controllerWasPlaying) {
          controller.play();
        }
      },
      onTapDown: (TapDownDetails details) {
        if (!controller.valueNotifier.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
    );
  }
}

/// Displays the play/buffering status of the video controlled by [controller].
///
/// If [allowScrubbing] is true, this widget will detect taps and drags and
/// seek the video accordingly.
///
/// [padding] allows to specify some extra padding around the progress indicator
/// that will also detect the gestures.
class VideoProgressIndicator extends StatefulWidget {
  VideoProgressIndicator(
    this.controller, {
    VideoProgressColors colors,
    this.allowScrubbing,
    this.padding = const EdgeInsets.only(top: 5.0),
  }) : colors = colors ?? VideoProgressColors();

  final MediaPlayer controller;
  final VideoProgressColors colors;
  final bool allowScrubbing;
  final EdgeInsets padding;

  @override
  _VideoProgressIndicatorState createState() => _VideoProgressIndicatorState();
}

class _VideoProgressIndicatorState extends State<VideoProgressIndicator> {
  _VideoProgressIndicatorState() {
    listener = () {
      if (!mounted) {
        return;
      }
      setState(() {});
    };
  }

  VoidCallback listener;

  MediaPlayer get controller => widget.controller;
  VideoProgressColors get colors => widget.colors;

  @override
  void initState() {
    super.initState();
    controller.valueNotifier.addListener(listener);
  }

  @override
  void deactivate() {
    controller.valueNotifier.removeListener(listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    Widget progressIndicator;
    if (controller.valueNotifier.value.initialized) {
      final int duration =
          controller.valueNotifier.value.duration.inMilliseconds;
      final int position =
          controller.valueNotifier.value.position.inMilliseconds;

      int maxBuffering = 0;
      for (DurationRange range in controller.valueNotifier.value.buffered) {
        final int end = range.end.inMilliseconds;
        if (end > maxBuffering) {
          maxBuffering = end;
        }
      }

      progressIndicator = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          LinearProgressIndicator(
            value: maxBuffering / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.bufferedColor),
            backgroundColor: colors.backgroundColor,
          ),
          LinearProgressIndicator(
            value: position / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
            backgroundColor: Colors.transparent,
          ),
        ],
      );
    } else {
      progressIndicator = LinearProgressIndicator(
        value: null,
        valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
        backgroundColor: colors.backgroundColor,
      );
    }
    final Widget paddedProgressIndicator = Padding(
      padding: widget.padding,
      child: progressIndicator,
    );
    if (widget.allowScrubbing) {
      return _VideoScrubber(
        child: paddedProgressIndicator,
        controller: controller,
      );
    } else {
      return paddedProgressIndicator;
    }
  }
}

class VideoPlayerView extends StatefulWidget {
  final MediaPlayer player;

  VideoPlayerView(this.player);

  @override
  VideoPlayerViewState createState() {
    return new VideoPlayerViewState();
  }
}

class VideoPlayerViewState extends State<VideoPlayerView> {
  double aspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    widget.player.valueNotifier.addListener(() {
      if (!mounted) return;
      if (widget.player.valueNotifier.value.aspectRatio != aspectRatio) {
        setState(() {
          aspectRatio = widget.player.valueNotifier.value.aspectRatio;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: (aspectRatio > 0.0) ? aspectRatio : 16 / 9,
        child: (widget.player.textureId != null)
            ? Texture(textureId: widget.player.textureId)
            : Container(color: Colors.black),
      ),
    );
  }
}
