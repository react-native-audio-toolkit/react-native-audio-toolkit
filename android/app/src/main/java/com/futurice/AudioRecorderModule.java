package com.futurice;

import android.media.MediaPlayer;
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

/**
 * Created by jvah on 15/06/16.
 */
public class AudioRecorderModule extends ReactContextBaseJavaModule implements MediaRecorder.OnInfoListener,
        MediaRecorder.OnErrorListener {
    private static final String LOG_TAG = "AudioRecorderModule";

    private String outputPath;

    private MediaRecorder mRecorder = null;
    private MediaPlayer mPlayer = null;

    public AudioRecorderModule(ReactApplicationContext reactContext) {
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
            emitError("playbackError", "Attempted to destroy null mPlayer");
            return;
        }

        mPlayer.reset();
        mPlayer.release();
        mPlayer = null;
    }

    private void destroy_mRecorder() {
        if (mRecorder == null) {
            emitError("recordingError", "Attempted to destroy null mRecorder");
            return;
        }

        mRecorder.reset();
        mRecorder.release();
        mRecorder = null;
    }

    @Override
    public String getName() {
        return "AudioRecorder";
    }

    @ReactMethod
    public void startRecordingToFilename(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            emitError("recordingError", "No filename provided");
        } else {
            path += "/" + filename;
            startRecording(path);
        }
    }

    @ReactMethod
    public void startRecording(String path) {
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
            mRecorder.setOnErrorListener(this);
            mRecorder.setOnInfoListener(this);
            mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);

            mRecorder.prepare();
            mRecorder.start();
            Log.d(LOG_TAG, "Recording started");

            emitEvent("recordingStarted", path);
        } catch (Exception e) {
            emitError("recordingError", e.toString());
            destroy_mRecorder();
        }
    }

    @ReactMethod
    public void stopRecording() {
        if (mRecorder == null) {
            emitError("recordingError", "Not prepared for recording");
            return;
        }

        try {
            mRecorder.stop();
            mRecorder.reset();

            emitEvent("recordingStopped", outputPath);
            destroy_mRecorder();
        } catch (Exception e) {
            emitError("recordingError", e.toString());
            destroy_mRecorder();
        }
    }

    @ReactMethod
    public void pauseRecording() {
        Log.e(LOG_TAG, "pauseRecording() not supported");

    }

    @ReactMethod
    public void playAudioWithFilename(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            emitError("playbackError", "No filename provided");
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

        try {
            outputPath = path;
            mPlayer.setDataSource(path);
        } catch (IOException e) {
            emitError("playbackError", e.toString());
            destroy_mPlayer();
        }

        try {
            mPlayer.prepare();
            mPlayer.start();

            emitEvent("playbackStarted", path);
        } catch (Exception e) {
            emitError("playbackError", e.toString());
            destroy_mPlayer();
        }
    }

    @ReactMethod
    public void pausePlayback() {
        if (mPlayer == null) {
            emitError("playbackError", "No media prepared");
            return;
        }

        try {
            mPlayer.pause();
            emitEvent("playbackPaused", outputPath);

        } catch (Exception e) {
            destroy_mPlayer();
            emitError("playbackError", e.toString());
        }
    }

    @ReactMethod
    public void resumePlayback() {
        if (mPlayer == null) {
            emitError("playbackError", "No media prepared");
            return;
        }

        try {
            mPlayer.start();
            emitEvent("playbackResumed", outputPath);
        } catch (Exception e) {
            destroy_mPlayer();
            emitError("playbackError", e.toString());
        }
    }

    @ReactMethod
    public void stopPlayback() {
        if (mPlayer == null) {
            emitError("playbackError", "No media prepared");
            return;
        }

        try {
            mPlayer.stop();
            destroy_mPlayer();
            emitEvent("playbackStopped", outputPath);
        } catch (Exception e) {
            destroy_mPlayer();
            emitError("playbackError", e.toString());
        }
    }

    @Override
    public void onError(MediaRecorder mr, int what, int extra) {
        destroy_mPlayer();
        emitError("recordingError", "Error during recording - what: " + what + " extra: " + extra);
    }

    @Override
    public void onInfo(MediaRecorder mr, int what, int extra) {
        destroy_mPlayer();
        emitEvent("recordingInfo", "Info during recording - what: " + what + " extra: " + extra);
    }
}
