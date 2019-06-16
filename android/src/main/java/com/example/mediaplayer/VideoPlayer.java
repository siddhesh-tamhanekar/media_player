package com.example.mediaplayer;

import android.content.Context;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.view.Surface;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

import com.google.android.exoplayer2.source.ConcatenatingMediaSource;
import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.Player.DefaultEventListener;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.audio.AudioAttributes;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.TrackSelector;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;
import com.google.android.exoplayer2.Timeline;
import android.support.annotation.Nullable;

import static com.google.android.exoplayer2.Player.REPEAT_MODE_ALL;
import static com.google.android.exoplayer2.Player.REPEAT_MODE_OFF;

class VideoPlayer {

    private SimpleExoPlayer exoPlayer;

    private int prevValue;
    private Surface surface;

    private final TextureRegistry.SurfaceTextureEntry textureEntry;

    private QueuingEventSink eventSink = new QueuingEventSink();

    private final EventChannel eventChannel;
    private final String TAG = "VideoPlayer.java";
    private boolean isInitialized = false;
    private Context context;
    private Map source = new HashMap<>();
    private List<Map> playlist = Collections.emptyList();

    public SimpleExoPlayer getPlayer() {
        return exoPlayer;
    }

    VideoPlayer(Context context, EventChannel eventChannel, TextureRegistry.SurfaceTextureEntry textureEntry,
            MethodChannel.Result result) {
        Log.i(TAG, "VideoPlayer constuctor");
        this.context = context;
        this.eventChannel = eventChannel;
        this.textureEntry = textureEntry;

        TrackSelector trackSelector = new DefaultTrackSelector();

        exoPlayer = ExoPlayerFactory.newSimpleInstance(context, trackSelector);

        setupVideoPlayer(eventChannel, textureEntry, result);
    }

    Map getCurrentPlayingSourceDetails() {
        if (!source.isEmpty())
            return source;
        if (playlist.size() != 0) {
            return playlist.get(exoPlayer.getCurrentWindowIndex());
        }
        return new HashMap<>();

    }

    void setSource(Map dataSource, MethodChannel.Result result) {
        isInitialized = false;

        source = dataSource;
        MediaSource mediaSource;
        Uri uri = Uri.parse((String) dataSource.get("source"));

        DataSource.Factory dataSourceFactory;
        if (uri.getScheme().equals("asset") || uri.getScheme().equals("file")) {
            dataSourceFactory = new DefaultDataSourceFactory(context, "ExoPlayer");
        } else {
            dataSourceFactory = new DefaultHttpDataSourceFactory("ExoPlayer", null,
                    DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS,
                    DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS, true);
        }

        mediaSource = buildMediaSource(uri, dataSourceFactory, context);
        exoPlayer.prepare(mediaSource);

        result.success(null);
    }

    void setPlaylist(List<Map> dataSourceList, MethodChannel.Result result) {
        isInitialized = false;
        source = new HashMap<>();
        playlist = dataSourceList;
        ConcatenatingMediaSource concatenatingMediaSource = new ConcatenatingMediaSource();
        for (int i = 0; i < playlist.size(); i++) {
            Uri uri = Uri.parse((String) playlist.get(i).get("source"));

            DataSource.Factory dataSourceFactory;
            if (uri.getScheme().equals("asset") || uri.getScheme().equals("file")) {
                dataSourceFactory = new DefaultDataSourceFactory(context, "ExoPlayer");
            } else {
                dataSourceFactory = new DefaultHttpDataSourceFactory("ExoPlayer", null,
                        DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS,
                        DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS, true);
            }

            MediaSource mediaSource = buildMediaSource(uri, dataSourceFactory, context);
            concatenatingMediaSource.addMediaSource(mediaSource);
        }
        exoPlayer.prepare(concatenatingMediaSource);

        result.success(null);
    }

    private MediaSource buildMediaSource(Uri uri, DataSource.Factory mediaDataSourceFactory, Context context) {
        int type = Util.inferContentType(uri.getLastPathSegment());
        switch (type) {
        case C.TYPE_SS:
            return new SsMediaSource.Factory(new DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                    new DefaultDataSourceFactory(context, null, mediaDataSourceFactory)).createMediaSource(uri);
        case C.TYPE_DASH:
            return new DashMediaSource.Factory(new DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                    new DefaultDataSourceFactory(context, null, mediaDataSourceFactory)).createMediaSource(uri);
        case C.TYPE_HLS:
            return new HlsMediaSource.Factory(mediaDataSourceFactory).createMediaSource(uri);
        case C.TYPE_OTHER:
            return new ExtractorMediaSource.Factory(mediaDataSourceFactory)
                    .setExtractorsFactory(new DefaultExtractorsFactory()).createMediaSource(uri);
        default: {
            throw new IllegalStateException("Unsupported type: " + type);
        }
        }
    }

    private void setupVideoPlayer(EventChannel eventChannel, TextureRegistry.SurfaceTextureEntry textureEntry,
            MethodChannel.Result result) {

        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object o, EventChannel.EventSink sink) {
                eventSink.setDelegate(sink);
            }

            @Override
            public void onCancel(Object o) {
                eventSink.setDelegate(null);
            }
        });

        surface = new Surface(textureEntry.surfaceTexture());
        exoPlayer.setVideoSurface(surface);
        setAudioAttributes(exoPlayer);

        exoPlayer.addListener(new DefaultEventListener() {

            @Override
            public void onPositionDiscontinuity(@Player.DiscontinuityReason int reason) {
                Log.i(TAG, "position changed called" + reason);
                if ((reason == 1 || reason == 2) && prevValue != exoPlayer.getCurrentWindowIndex()){
                    isInitialized = false;                    
                    sendInitialized();
                }
            }

            @Override
            public void onPlayerStateChanged(final boolean playWhenReady, final int playbackState) {
                super.onPlayerStateChanged(playWhenReady, playbackState);

                if (playbackState == Player.STATE_BUFFERING) {
                    Map<String, Object> event = new HashMap<>();
                    event.put("event", "bufferingUpdate");
                    List<Integer> range = Arrays.asList(0, exoPlayer.getBufferedPercentage());
                    // iOS supports a list of buffered ranges, so here is a list with a single
                    // range.
                    event.put("values", Collections.singletonList(range));
                    eventSink.success(event);
                } else if (playbackState == Player.STATE_READY && !isInitialized) {
                    isInitialized = true;
                    sendInitialized();
                } else if (playWhenReady && playbackState == Player.STATE_READY) {
                    Map<String, Object> event = new HashMap<>();
                    event.put("event", "play");
                    eventSink.success(event);
                } else if (!playWhenReady && playbackState == Player.STATE_READY) {
                    Map<String, Object> event = new HashMap<>();
                    event.put("event", "paused");
                    eventSink.success(event);
                }
            }

            @Override
            public void onPlayerError(final ExoPlaybackException error) {
                super.onPlayerError(error);
                if (eventSink != null) {
                    isInitialized = false;
                    eventSink.error("VideoError", "Video player had error " + error, null);
                }
            }
        });

        Map<String, Object> reply = new HashMap<>();
        reply.put("textureId", textureEntry.id());
        result.success(reply);
    }

    @SuppressWarnings("deprecation")
    private static void setAudioAttributes(SimpleExoPlayer exoPlayer) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            exoPlayer.setAudioAttributes(new AudioAttributes.Builder().setContentType(C.CONTENT_TYPE_MOVIE).build());
        } else {
            exoPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
        }
    }

    void play() {

        exoPlayer.setPlayWhenReady(true);
    }

    void retry(){
         Log.i(TAG, "retry called");
        exoPlayer.retry();
        
         Log.i(TAG, "retry called after exoplayer retry.");
        // exoPlayer.setPlayWhenReady();
    }

    void pause() {
        exoPlayer.setPlayWhenReady(false);
    }

    void setLooping(boolean value) {
        exoPlayer.setRepeatMode(value ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
    }

    void setVolume(double value) {
        float bracketedValue = (float) Math.max(0.0, Math.min(1.0, value));
        exoPlayer.setVolume(bracketedValue);
    }

    void seekTo(int location, int index) {
        if (index < 0) {
            exoPlayer.seekTo(location);

        } else {
            if (index != exoPlayer.getCurrentWindowIndex()) {
                Log.i(TAG, "seekTo isinitialized set to false");
                isInitialized = false;
            }
            exoPlayer.seekTo(index, location);
        }
    }

    long getPosition() {
        return exoPlayer.getCurrentPosition();
    }

    private void sendInitialized() {
        if (isInitialized) {
            prevValue = exoPlayer.getCurrentWindowIndex();
            Map<String, Object> event = new HashMap<>();
            event.put("event", "initialized");
            event.put("current_index", exoPlayer.getCurrentWindowIndex());
            event.put("duration", exoPlayer.getDuration());
            if (exoPlayer.getVideoFormat() != null) {
                event.put("width", exoPlayer.getVideoFormat().width);
                event.put("height", exoPlayer.getVideoFormat().height);
            }
            eventSink.success(event);
        }
    }

    void dispose() {
        Log.i(TAG, "dispose called");
        if (isInitialized) {
            exoPlayer.stop();
            Log.i(TAG, "exoplayer stopped");
        }
        textureEntry.release();
        Log.i(TAG, "textureenry released");
        eventChannel.setStreamHandler(null);
        Log.i(TAG, "event channel stopped");

        if (surface != null) {
            surface.release();
            Log.i(TAG, "surface released");

        }
        if (exoPlayer != null) {
            exoPlayer.release();
            Log.i(TAG, "exoplayer released");

        }
    }
}