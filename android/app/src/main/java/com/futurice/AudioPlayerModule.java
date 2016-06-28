package com.futurice;

import android.media.MediaPlayer;
import android.os.Environment;
import android.support.annotation.Nullable;
import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.io.IOException;

public class AudioPlayerModule extends ReactContextBaseJavaModule implements MediaPlayer.OnInfoListener,
        MediaPlayer.OnErrorListener, MediaPlayer.OnCompletionListener {
    private static final String LOG_TAG = "AudioPlayerModule";

    private String outputPath;

    private MediaPlayer mPlayer = null;

    public AudioPlayerModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    private void emitError(String event, String s) {
        Log.e(LOG_TAG, event + ": " + s);
        WritableMap payload = new WritableNativeMap();
        payload.putString(event, s);

        getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(event, payload);
    }

    private void emitEvent(String event, String s) {
        Log.d(LOG_TAG, event + ": " + s);
        WritableMap payload = new WritableNativeMap();
        payload.putString(event, s);

        getReactApplicationContext()
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(event, payload);
    }

    private void destroy_mPlayer() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "Attempted to destroy null mPlayer");
            return;
        }

        mPlayer.reset();
        mPlayer.release();
        mPlayer = null;
    }

    @Override
    public String getName() {
        return "AudioPlayer";
    }

    @ReactMethod
    public void playAudioWithFilename(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            emitError("RCTAudioPlayer:error", "No filename provided");
        } else {
            path += "/" + filename;
            playAudioOnPath(path);
        }
    }

    @ReactMethod
    public void playAudioOnPath(String path) {
        if (mPlayer == null) {
            mPlayer = new MediaPlayer();
        }

        mPlayer.reset();
        mPlayer.setOnErrorListener(this);
        mPlayer.setOnInfoListener(this);
        mPlayer.setOnCompletionListener(this);

        try {
            outputPath = path;
            mPlayer.setDataSource(path);
        } catch (IOException e) {
            emitError("RCTAudioPlayer:error", e.toString());
            destroy_mPlayer();
            return;
        }

        try {
            mPlayer.prepare();
            mPlayer.start();

            emitEvent("RCTAudioPlayer:playing", path);
        } catch (Exception e) {
            emitError("RCTAudioPlayer:error", e.toString());
            destroy_mPlayer();
        }
    }

    @ReactMethod
    public void pausePlayback() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "No media prepared");
            return;
        }

        try {
            mPlayer.pause();
            emitEvent("RCTAudioPlayer:pause", outputPath);

        } catch (Exception e) {
            destroy_mPlayer();
            emitError("RCTAudioPlayer:error", e.toString());
        }
    }

    @ReactMethod
    public void resumePlayback() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "No media prepared");
            return;
        }

        try {
            mPlayer.start();
            emitEvent("RCTAudioPlayer:play", outputPath);
            emitEvent("RCTAudioPlayer:playing", outputPath);
        } catch (Exception e) {
            destroy_mPlayer();
            emitError("RCTAudioPlayer:error", e.toString());
        }
    }

    @ReactMethod
    public void stopPlayback() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "No media prepared");
            return;
        }

        try {
            mPlayer.stop();
            destroy_mPlayer();
            emitEvent("RCTAudioPlayer:abort", "Stopped playback");
        } catch (Exception e) {
            destroy_mPlayer();
            emitError("RCTAudioPlayer:error", e.toString());
        }
    }

    @Override
    public void onCompletion(MediaPlayer mp) {
        destroy_mPlayer();
        emitEvent("RCTAudioPlayer:ended", "Finished playback");
    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        destroy_mPlayer();
        emitError("RCTAudioPlayer:error", "Error during playback - what: " + what + " extra: " + extra);
        return true; // don't call onCompletion listener afterwards
    }

    @Override
    public boolean onInfo(MediaPlayer mp, int what, int extra) {
        // TODO: what to do with this
        emitEvent("RCTAudioPlayer:info", "Info during playback - what: " + what + " extra: " + extra);
        return false;
    }
}
