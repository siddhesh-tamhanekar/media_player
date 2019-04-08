package com.example.mediaplayer;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.PluginRegistry.ViewDestroyListener;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.TextureRegistry;
import io.flutter.plugin.common.EventChannel;

import java.util.HashMap;
import java.util.Map;

import java.util.List;

import android.content.Context;
import android.util.Log;
import android.widget.Toast;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.Message;
import android.os.Handler;
import android.os.IBinder;
import android.content.ComponentName;

/** MediaPlayerPlugin */
public class MediaPlayerPlugin implements MethodCallHandler, ViewDestroyListener {



  private final String TAG = "MediaPlayerPlugin";
  private Registrar registrar;

  private AudioServiceBinder audioServiceBinder = null;
  private TextureRegistry textures;

  private HashMap<Long, VideoPlayer> videoPlayers = new HashMap<>();

  private MethodCall call = null;
  private Result result = null;

  private ServiceConnection serviceConnection = new ServiceConnection() {
    @Override
    public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
      Log.i("ServiceConnnection", "Service connection audio service binder");
      audioServiceBinder = (AudioServiceBinder) iBinder;
      createVideoPlayer();
      Log.i("ServiceConnnection", "Service connection audio service binder complete");
    }



    @Override
    public void onServiceDisconnected(ComponentName componentName) {
    Log.i("ServiceConnnection", "Service disconnected");
  
    }
  };

  private MediaPlayerPlugin(Registrar registrar) {
    this.registrar = registrar;
  }

  public void createVideoPlayer() {

      this.registrar.addViewDestroyListener(this);

    if (call.argument("isBackground")) {
      audioServiceBinder.create(registrar, call, result);

    } else {
      // if not background then add it into
      TextureRegistry.SurfaceTextureEntry handle = registrar.textures().createSurfaceTexture();
      EventChannel eventChannel = new EventChannel(registrar.messenger(), "media_player_event_channel" + handle.id());

      Log.d(TAG, "createVideoPlayer: media_player_event_channel" + handle.id());
      VideoPlayer player;

      player = new VideoPlayer(registrar.context(), eventChannel, handle, result);
      videoPlayers.put(handle.id(), player);

    }

  }

  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "com.example.media_player");
    MediaPlayerPlugin plugin = new MediaPlayerPlugin(registrar);
    channel.setMethodCallHandler(plugin);
  }

  @Override
  public boolean onViewDestroy(FlutterNativeView flutterNativeView) {
    Log.i(TAG,"onview destroy called");
    unBoundService();
    return false;
  }

  private void bindService() {

    if (audioServiceBinder == null) {
      Log.i(TAG, "binding service");
      Intent intent = new Intent(registrar.context(), AudioService.class);
      registrar.context().bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
    }
  }

  private void unBoundService() {
    Log.i(TAG, "unbound service called");
    if (audioServiceBinder != null){
      audioServiceBinder.destroyAllPlayers();
      registrar.context().unbindService(serviceConnection);
    Log.i(TAG, "service unbounded");

    }
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {

    // Log.i(TAG, "method call = " + call.method);
    switch (call.method) {

    case "create": {
      // if service is not created and app demands background player then we
      // have to call createVideoPlayer from onServiceConnected callback;
      // so let's save call and result and createVideoplayer will
      this.call = call;
      this.result = result;
      if (call.argument("isBackground")) {
        Log.i(TAG, "neeeded background exoplayer");

        if (audioServiceBinder == null) {
          Log.i(TAG, "calling BindeService");
          bindService();
        } else {
          createVideoPlayer();
        }
      } else {

        createVideoPlayer();
      }

      break;
    }
    default: {
      long textureId = ((Number) call.argument("textureId")).longValue();
      boolean background = call.argument("isBackground");
      VideoPlayer player = null;
      // Log.i(TAG, "TextureID: " + textureId + " background:" + background);
      if (background) {
        if (audioServiceBinder != null)
          player = audioServiceBinder.getPlayer(textureId);
      } else {
        // Log.i(TAG, "calling frontend player");
        player = videoPlayers.get(textureId);
      }

      if (!call.method.equals("position")) {
        // Log.i(TAG, "method called " + call.method);
      }
      if (player == null) {
        result.error("Unknown textureId", "No video player associated with texture id " + textureId, null);
        return;
      }
      onMethodCall(call, result, textureId, player);
      break;
    }
    }

  }

  private void onMethodCall(MethodCall call, Result result, long textureId, VideoPlayer player) {

      switch (call.method) {
    case "setSource":
      Map source = (HashMap) call.argument("source");
      Log.d(TAG, "Source=" + source.toString());
      player.setSource(source, result);
      // result.success(null);
      break;
    case "setPlaylist":
      List<Map> playlist = (List<Map>) call.argument("playlist");
      Log.d(TAG, "Playlist=" + playlist.toString());
      player.setPlaylist(playlist, result);
      // result.success(null);
      break;
    case "setLooping":
      player.setLooping((Boolean) call.argument("looping"));
      result.success(null);
      break;
    case "setVolume":
      player.setVolume((Double) call.argument("volume"));
      result.success(null);
      break;
    case "play":
      Log.i(TAG, "method call play");
      player.play();
      result.success(null);
      break;
    case "pause":
      player.pause();
      result.success(null);
      break;
    case "seekTo":
      int location = ((Number) call.argument("location")).intValue();
      int index = ((Number) call.argument("index")).intValue();
      player.seekTo(location, index);
      result.success(null);
      break;
    case "position":
      result.success(player.getPosition());
      break;
    case "dispose":
       Log.d(TAG, "calling dispose on player instance android");
      player.dispose();
      boolean background = call.argument("isBackground");
      if (background)
        audioServiceBinder.removePlayer(textureId);
      else
        videoPlayers.remove(textureId);
      result.success(null);
      break;
    case "retry":
      player.retry();
      result.success(null);
      break;  
    default:
      result.notImplemented();
      break;
    }
  }

}
