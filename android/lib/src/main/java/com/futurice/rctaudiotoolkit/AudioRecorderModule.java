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

    private String outputPath;

    private MediaRecorder mRecorder = null;
    private ReactApplicationContext context;

    public AudioRecorderModule(ReactApplicationContext reactContext) {
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

    private void destroy_mRecorder() {
        if (mRecorder == null) {
            emitError("RCTAudioRecorder:error", "Attempted to destroy null mRecorder");
            return;
        }

        mRecorder.reset();
        mRecorder.release();
        mRecorder = null;
    }

    @Override
    public String getName() {
        return "RCTAudioRecorder";
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
