package com.futurice.rctaudiotoolkit;

import android.media.MediaRecorder;
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

public class AudioRecorderModule extends ReactContextBaseJavaModule implements MediaRecorder.OnInfoListener,
        MediaRecorder.OnErrorListener {
    private static final String LOG_TAG = "AudioRecorderModule";

    Map<Integer, MediaRecorder> recorderPool = new HashMap<>();
    Map<Integer, Boolean> recorderAutoDestroy = new HashMap<>();

    private ReactApplicationContext context;

    public AudioRecorderModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
    }

    @Override
    public String getName() {
        return "RCTAudioRecorder";
    }

    private void emitEvent(Integer playerId, String event, WritableMap data) {
        //Log.d(LOG_TAG, "player " + playerId + ": " + event + ": " + s);
        WritableMap payload = new WritableNativeMap();
        payload.putString("event", event);
        payload.putMap("data", data);

        this.context
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("RCTAudioRecorderEvent:" + playerId, payload);
    }

    private WritableMap errObj(final String code, final String message) {
        WritableMap err = Arguments.createMap();

        StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
        String stackTraceString = "";

        for (StackTraceElement e : stackTrace) {
            stackTraceString += e.toString() + "\n";
        }

        err.putString("err", code);
        err.putString("message", message);
        err.putString("stackTrace", stackTraceString);

        Log.e(LOG_TAG, message);
        Log.d(LOG_TAG, stackTraceString);

        return err;
    }

    private int formatFromPath(String path) {
        String ext = path.substring(path.lastIndexOf('.'));

        switch (ext) {
            case ".aac":
                return MediaRecorder.OutputFormat.AAC_ADTS;
            case ".mp4":
                return MediaRecorder.OutputFormat.MPEG_4;
            case ".webm":
            case ".ogg":
                return MediaRecorder.OutputFormat.WEBM;
            case ".amr":
                return MediaRecorder.OutputFormat.AMR_WB;
            default:
                return MediaRecorder.OutputFormat.DEFAULT;
        }
    }

    private int encoderFromPath(String path) {
        String ext = path.substring(path.lastIndexOf('.'));

        switch (ext) {
            case ".aac":
            case ".mp4":
                return MediaRecorder.AudioEncoder.HE_AAC;
            case ".webm":
            case ".ogg":
                return MediaRecorder.AudioEncoder.VORBIS;
            case ".amr":
                return MediaRecorder.AudioEncoder.AMR_WB;
            default:
                return MediaRecorder.AudioEncoder.DEFAULT;
        }
    }

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


    private void destroy_mRecorder() {
        if (mRecorder == null) {
            emitError("RCTAudioRecorder:error", "Attempted to destroy null mRecorder");
            return;
        }

        mRecorder.reset();
        mRecorder.release();
        mRecorder = null;
    }

    @ReactMethod
    public void recordLocal(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            emitError("RCTAudioRecorder:error", "No filename provided");
        } else {
            path += "/" + filename;
            record(path);
        }
    }

    @ReactMethod
    public void record(String path) {
        if (mRecorder == null) {
            mRecorder = new MediaRecorder();
        } else {
            Log.e(LOG_TAG, "Media recorder already recording!");
            return;
        }

        outputPath = path;

        try {
            // See the state diagram at
            // https://developer.android.com/reference/android/media/MediaRecorder.html
            mRecorder.reset();

            mRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            // Android music player cannot play ADTS so let's use MPEG_4
            mRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mRecorder.setOutputFile(path);
            mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);

            mRecorder.setOnErrorListener(this);
            mRecorder.setOnInfoListener(this);
            mRecorder.prepare();
            mRecorder.start();
            Log.d(LOG_TAG, "Recording started");

            emitEvent("RCTAudioRecorder:start", path);
        } catch (Exception e) {
            emitError("RCTAudioRecorder:error", e.toString());
            destroy_mRecorder();
        }
    }

    @ReactMethod
    public void stop() {
        if (mRecorder == null) {
            emitError("RCTAudioRecorder:error", "Not prepared for recording");
            return;
        }

        try {
            mRecorder.stop();
            mRecorder.reset();

            emitEvent("RCTAudioRecorder:ended", outputPath);
            destroy_mRecorder();
        } catch (Exception e) {
            emitError("RCTAudioRecorder:error", e.toString());
            destroy_mRecorder();
        }
    }

    @ReactMethod
    public void pause() {
        Log.e(LOG_TAG, "pause() not implemented");

    }

    @Override
    public void onError(MediaRecorder mr, int what, int extra) {
        destroy_mRecorder();
        emitError("RCTAudioRecorder:error", "Error during recording - what: " + what + " extra: " + extra);
    }

    @Override
    public void onInfo(MediaRecorder mr, int what, int extra) {
        // TODO: what to do about this
        emitEvent("RCTAudioRecorder:info", "Info during recording - what: " + what + " extra: " + extra);
    }
}
