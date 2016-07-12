package com.futurice.rctaudiotoolkit;

import android.media.MediaPlayer;
import android.media.PlaybackParams;
import android.os.Environment;
import android.os.PowerManager;
import android.support.annotation.Nullable;
import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.io.IOException;

public class AudioPlayerModule extends ReactContextBaseJavaModule implements MediaPlayer.OnInfoListener,
        MediaPlayer.OnErrorListener, MediaPlayer.OnCompletionListener {
    private static final String LOG_TAG = "AudioPlayerModule";

    private MediaPlayer mPlayer = null;
    private ReactApplicationContext context;
    private boolean prepared = false;

    public AudioPlayerModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
    }

    private void emitError(String event, String s) {
        Log.e(LOG_TAG, event + ": " + s);
        WritableMap payload = new WritableNativeMap();
        payload.putString(event, s);

        this.context
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(event, payload);
    }

    private void emitEvent(String event, String s) {
        Log.d(LOG_TAG, event + ": " + s);
        WritableMap payload = new WritableNativeMap();
        payload.putString(event, s);

        this.context
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
        return "RCTAudioPlayer";
    }

    @ReactMethod
    public void playLocal(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            emitError("RCTAudioPlayer:error", "No filename provided");
        } else {
            path += "/" + filename;
            play(path);
        }
    }

    private void initPlayer() {
        if (mPlayer != null) {
            destroy_mPlayer();
        }

        mPlayer = new MediaPlayer();

        mPlayer.reset();
        mPlayer.setOnErrorListener(this);
        mPlayer.setOnInfoListener(this);
        mPlayer.setOnCompletionListener(this);

        prepared = false;
    }

    @ReactMethod
    public void prepare(String path, Callback callback, ReadableMap options) {
        if (mPlayer == null) {
            initPlayer();
        }

        try {
            if (options.getBoolean("local")) {
                path = Environment.getExternalStorageDirectory().getAbsolutePath()
                    + "/" + path;
            }

            if (options.getBoolean("partialWakeLock")) {
                mPlayer.setWakeMode(this.context, PowerManager.PARTIAL_WAKE_LOCK);
            }

            if (!options.isNull("volume")) {
                double vol = options.getDouble("volume");
                mPlayer.setVolume((float) vol, (float) vol);
            }

            if (!options.isNull("speed") || !options.isNull("pitch")) {
                PlaybackParams params = new PlaybackParams();

                if (!options.isNull("speed")) {
                    params.setSpeed((float) options.getDouble("speed"));
                }

                if (!options.isNull("pitch")) {
                    params.setPitch((float) options.getDouble("speed"));
                }

                mPlayer.setPlaybackParams(params);
            }

            mPlayer.setDataSource(path);
            mPlayer.prepare();

            if (callback != null) {
                callback.invoke((String) null);
            }
        } catch (Exception e) {
            if (callback != null) {
                callback.invoke(e.toString());
            } else {
                emitError("RCTAudioPlayer:error", e.toString());
            }

            destroy_mPlayer();
            return;
        }
    }

    @ReactMethod
    public void play(String path) {
        if (mPlayer == null) {
            initPlayer();
        }

        if (path != null && !path.isEmpty()) {
            prepare(path, null, null);
        }

        try {
            mPlayer.start();

            emitEvent("RCTAudioPlayer:playing", "Playback started");
        } catch (Exception e) {
            emitError("RCTAudioPlayer:error", e.toString());
            destroy_mPlayer();
        }
    }

    @ReactMethod
    public void pause() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "No media prepared");
            return;
        }

        try {
            mPlayer.pause();
            emitEvent("RCTAudioPlayer:pause", "Playback paused");

        } catch (Exception e) {
            destroy_mPlayer();
            emitError("RCTAudioPlayer:error", e.toString());
        }
    }

    @ReactMethod
    public void resume() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "No media prepared");
            return;
        }

        try {
            mPlayer.start();
            emitEvent("RCTAudioPlayer:play", "Playback resumed");
            emitEvent("RCTAudioPlayer:playing", "Playback started");
        } catch (Exception e) {
            destroy_mPlayer();
            emitError("RCTAudioPlayer:error", e.toString());
        }
    }

    @ReactMethod
    public void stop() {
        if (mPlayer == null) {
            emitError("RCTAudioPlayer:error", "No media prepared");
            return;
        }

        try {
            mPlayer.stop();
            destroy_mPlayer();
            emitEvent("RCTAudioPlayer:ended", "Stopped playback");
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
