package com.futurice.rctaudiotoolkit;

import android.media.MediaPlayer;
import android.media.PlaybackParams;
import android.media.AudioAttributes;
import android.media.AudioAttributes.Builder;
import android.os.Environment;
import android.os.PowerManager;
import android.support.annotation.Nullable;
import android.util.Log;
import android.net.Uri;

import com.facebook.react.bridge.Arguments;
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
import java.io.File;
import java.lang.Thread;
import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Objects;

public class AudioPlayerModule extends ReactContextBaseJavaModule implements MediaPlayer.OnInfoListener,
        MediaPlayer.OnErrorListener, MediaPlayer.OnCompletionListener {
    private static final String LOG_TAG = "AudioPlayerModule";

    Map<Integer, MediaPlayer> playerPool = new HashMap<>();
    Map<Integer, Boolean> playerAutoDestroy = new HashMap<>();

    private ReactApplicationContext context;

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

    /*
    public Map<String, Object> getConstants() {
        final Map<String, Object> constants = new HashMap<>();
        constants.put("PATH_BUNDLE", 
    }
    */

    private WritableMap errObj(final Integer code, final String message) {
        WritableMap err = Arguments.createMap();

        StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
        String stackTraceString = "";

        for (StackTraceElement e : stackTrace) {
            stackTraceString += e.toString() + "\n";
        }

        err.putInt("code", code);
        err.putString("message", message);
        err.putString("stackTrace", stackTraceString);

        Log.e(LOG_TAG, message);
        Log.d(LOG_TAG, stackTraceString);

        return err;
    }

    @Override
    public String getName() {
        return "RCTAudioPlayer";
    }

    /*
    @ReactMethod
    // TODO: deprecated
    public void playLocal(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            emitError("RCTAudioPlayer:error", "No filename provided");
        } else {
            path += "/" + filename;
            play(path, null, null);
        }
    }
    */

    /*
    @ReactMethod
    public void getResourceUri(String name, Callback callback) {
        int resId = this.context.getResources().getIdentifier(name, "raw", this.context.getPackageName());

        Uri uri = Uri.parse("android.resource://" + this.context.getPackageName() + "/" + resId);
        callback.invoke(uri.toString());
    }
    */

    /**
     * Get URI for a path on external storage.
     *
     * If extPath is empty, return URI for external storage directory.
     */
    /*
    @ReactMethod
    public void getExternalStorageUri(String extPath, Callback callback) {
        String completePath = Environment.getExternalStorageDirectory() +
            ((extPath == null || extPath.isEmpty()) ? "" : ("/" + extPath));

        File file = new File(completePath);
        Uri uri = Uri.fromFile(file);
        callback.invoke(uri.toString());
    }
    */

    private Uri uriFromPath(String path) {
        File file = null;

        // Try finding file in Android "raw" resources
        String fileNameWithoutExt;
        if (path.lastIndexOf('.') != -1) {
            fileNameWithoutExt = path.substring(0, path.lastIndexOf('.'));
        } else {
            fileNameWithoutExt = path;
        }

        int resId = this.context.getResources().getIdentifier(fileNameWithoutExt,
            "raw", this.context.getPackageName());
        if (resId != 0) {
            return Uri.parse("android.resource://" + this.context.getPackageName() + "/" + resId);
        }

        // Try finding file on sdcard
        String extPath = Environment.getExternalStorageDirectory() + "/" + path;
        file = new File(extPath);
        if (file.exists()) {
            return Uri.fromFile(file);
        }

        // Try finding file by full path
        file = new File(path);
        if (file.exists()) {
            return Uri.fromFile(file);
        }

        // Otherwise pass whole path string as URI and hope for the best
        return Uri.parse(path);
    }

    @ReactMethod
    public void destroyPlayer(Integer playerId) {
        MediaPlayer player = this.playerPool.get(playerId);

        if (player != null) {
            player.release();
            this.playerPool.remove(playerId);
            this.playerAutoDestroy.remove(playerId);
            emitEvent("RCTAudioPlayer:info", "Destroyed player: " + playerId);
        }
    }

    @ReactMethod
    public void prepare(Integer playerId, Callback callback) {
        MediaPlayer player = this.playerPool.get(playerId);
        if (player == null) {
            callback.invoke(errObj(-1, "playerId " + playerId + " not found."));
            return;
        }

        try {
            player.prepare();

            WritableMap info = Arguments.createMap();
            info.putDouble("duration", player.getDuration());
            info.putDouble("position", player.getCurrentPosition());
            info.putDouble("audioSessionId", player.getAudioSessionId());

            callback.invoke(null, info);
        } catch (IOException e) {
            callback.invoke(errObj(-1, e.toString()));
        }
    }

    @ReactMethod
    public void init(Integer playerId, String path, Callback callback) {
        if (path == null || path.isEmpty()) {
            callback.invoke(errObj(-1, "Provided path was empty"));
            return;
        }

        // Release old player if exists
        destroyPlayer(playerId);

        Uri uri = uriFromPath(path);

        //MediaPlayer player = MediaPlayer.create(this.context, uri, null, attributes);
        MediaPlayer player = new MediaPlayer();

        /*
        AudioAttributes attributes = new AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_UNKNOWN)
            .setContentType(AudioAttributes.CONTENT_TYPE_UNKNOWN)
            .build();

        player.setAudioAttributes(attributes);
        */

        try {
            player.setDataSource(this.context, uri);
        } catch (IOException e) {
            callback.invoke(errObj(-1, e.toString()));
            return;
        }

        player.setOnErrorListener(this);
        player.setOnInfoListener(this);
        player.setOnCompletionListener(this);

        this.playerPool.put(playerId, player);
        this.playerAutoDestroy.put(playerId, true);

        callback.invoke();
    }

    @ReactMethod
    public void set(Integer playerId, ReadableMap options, Callback callback) {
        MediaPlayer player = this.playerPool.get(playerId);
        if (player == null) {
            callback.invoke(errObj(-1, "playerId " + playerId + " not found."));
            return;
        }

        if (options.hasKey("wakeLock")) {
            // TODO: can we disable the wake lock also?
            if (options.getBoolean("wakeLock")) {
                player.setWakeMode(this.context, PowerManager.PARTIAL_WAKE_LOCK);
            }
        }

        if (options.hasKey("autoDestroy")) {
            this.playerAutoDestroy.put(playerId, options.getBoolean("autoDestroy"));
        }

        if (options.hasKey("volume") && !options.isNull("volume")) {
            double vol = options.getDouble("volume");
            player.setVolume((float) vol, (float) vol);
        }

        if (options.hasKey("speed") || options.hasKey("pitch")) {
            PlaybackParams params = new PlaybackParams();

            if (options.hasKey("speed") && !options.isNull("speed")) {
                params.setSpeed((float) options.getDouble("speed"));
            }

            if (options.hasKey("pitch") && !options.isNull("pitch")) {
                params.setPitch((float) options.getDouble("pitch"));
            }

            player.setPlaybackParams(params);
        }

        callback.invoke();
    }

    @ReactMethod
    public void play(Integer playerId, Integer position, Callback callback) {
        MediaPlayer player = this.playerPool.get(playerId);
        if (player == null) {
            callback.invoke(errObj(-1, "playerId " + playerId + "not found."));
            return;
        }

        try {
            player.start();
            if (position != -1) {
                player.seekTo(position);
            }

            WritableMap info = Arguments.createMap();
            info.putDouble("duration", player.getDuration());
            info.putDouble("position", player.getCurrentPosition());
            info.putDouble("audioSessionId", player.getAudioSessionId());

            callback.invoke(null, info);
        } catch (Exception e) {
            callback.invoke(errObj(-1, e.toString()));
        }
    }

    @ReactMethod
    public void pause(Integer playerId, Callback callback) {
        MediaPlayer player = this.playerPool.get(playerId);
        if (player == null) {
            callback.invoke(errObj(-1, "playerId " + playerId + "not found."));
            return;
        }

        try {
            player.pause();
            callback.invoke();
        } catch (Exception e) {
            callback.invoke(errObj(-1, e.toString()));
        }
    }

    @ReactMethod
    public void stop(Integer playerId, Callback callback) {
        MediaPlayer player = this.playerPool.get(playerId);
        if (player == null) {
            callback.invoke(errObj(-1, "playerId " + playerId + "not found."));
            return;
        }

        try {
            player.stop();
            if (this.playerAutoDestroy.get(playerId)) {
                destroyPlayer(playerId);
            }
            callback.invoke();
        } catch (Exception e) {
            callback.invoke(errObj(-1, e.toString()));
            emitError("RCTAudioPlayer:error", e.toString());
        }
    }

    // Find playerId matching player from playerPool
    private Integer getPlayerId(MediaPlayer player) {
        for (Entry<Integer, MediaPlayer> entry : playerPool.entrySet()) {
            if (Objects.equals(player, entry.getValue())) {
                return entry.getKey();
            }
        }

        return null;
    }

    @Override
    public void onCompletion(MediaPlayer player) {
        emitEvent("RCTAudioPlayer:ended", "Finished playback");

        Integer playerId = getPlayerId(player);

        if (this.playerAutoDestroy.get(playerId)) {
            destroyPlayer(playerId);
        }
    }

    @Override
    public boolean onError(MediaPlayer player, int what, int extra) {
        emitError("RCTAudioPlayer:error", "Error during playback - what: " + what + " extra: " + extra);

        Integer playerId = getPlayerId(player);
        destroyPlayer(playerId);
        return true; // don't call onCompletion listener afterwards
    }

    @Override
    public boolean onInfo(MediaPlayer player, int what, int extra) {
        // TODO: what to do with this
        emitEvent("RCTAudioPlayer:info", "Info during playback - what: " + what + " extra: " + extra);
        return false;
    }
}
