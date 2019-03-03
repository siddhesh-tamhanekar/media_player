package com.example.mediaplayer;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

public class AudioService extends Service {

    private AudioServiceBinder audioServiceBinder;

    public AudioService() {
        audioServiceBinder = new AudioServiceBinder(this);
    }

    @Override
    public IBinder onBind(Intent intent) {
        return audioServiceBinder;
    }
}
