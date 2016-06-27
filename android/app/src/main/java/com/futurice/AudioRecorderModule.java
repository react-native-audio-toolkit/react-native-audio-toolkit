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

    private boolean mRecorderRecording = false;
    private MediaRecorder mRecorder = null;
    private MediaPlayer mPlayer = null;

    public AudioRecorderModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }


    @Override
    public String getName() {
        return "AudioRecorder";
    }

    @ReactMethod
    public void prepareRecordinWithFilename(String filename) {
        String path = Environment.getExternalStorageDirectory().getAbsolutePath();
        if (filename == null) {
            path += "/audiorecordtest.mp4";
        } else {
            path += "/" + filename;
        }
        outputPath = path;

        // If we already have a recorder, destroy
        if (mRecorder != null) {
            mRecorder.reset();
            mRecorder.release();
            mRecorder = null;
        }
        mRecorder = new MediaRecorder();
        mRecorder.reset();

        this.prepare();
    }

    private void prepare() {
        Log.d(LOG_TAG, "Path: " + outputPath);
        // See the state diagram at https://developer.android.com/reference/android/media/MediaRecorder.html, it is good
        mRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        // Android music player cannot play ADTS so let's use MPEG_4
        mRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        mRecorder.setOutputFile(outputPath);
        mRecorder.setOnErrorListener(this);
        mRecorder.setOnInfoListener(this);
        mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);

        try {
            mRecorder.prepare();
        } catch (IOException e) {
            Log.e(LOG_TAG, "record prepare() failed");
        }
    }

    @ReactMethod
    public void startRecording() {
        if (mRecorder != null && !mRecorderRecording) {
            mRecorderRecording = true;
            try {
                mRecorder.start();
                WritableMap payload = new WritableNativeMap();
                payload.putString("path", outputPath);
                sendEvent(getReactApplicationContext(), "rec_start", payload);

            } catch (IllegalStateException e) {
                Log.d(LOG_TAG, "Recording start failed. start() called before prepare()");
                WritableMap payload = new WritableNativeMap();
                payload.putString("error", e.toString());
                sendEvent(getReactApplicationContext(), "rec_error", payload);
            }
            Log.d(LOG_TAG, "Recording started");
        }
    }

    @ReactMethod
    public void stopRecording() {
        if (mRecorder != null) {
            mRecorder.stop();
            mRecorder.reset();
            mRecorder.release();
            mRecorder = null;
            mRecorderRecording = false;

            WritableMap payload = new WritableNativeMap();
            payload.putString("path", outputPath);
            sendEvent(getReactApplicationContext(), "rec_end", payload);

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
            Log.e(LOG_TAG, "No file name provided to play file");
            WritableMap payload = new WritableNativeMap();
            payload.putString("error", "No filename provided");
            sendEvent(getReactApplicationContext(), "play_error", payload);
        } else {
            path += "/" + filename;
            playAudioOnPath(path);
        }
    }

    @ReactMethod
    public void playAudioOnPath(String path) {
        if (mRecorder != null && mRecorderRecording) {
            mPlayer.reset();
            mPlayer.release();
            mPlayer = null;
            Log.e(LOG_TAG, "stop the recording before playing");

            WritableMap payload = new WritableNativeMap();
            payload.putString("error", "Stop recording before playing");
            sendEvent(getReactApplicationContext(), "play_error", payload);

            return;
        }

        if (!mPlayer.isPlaying()) {
            if (mPlayer != null) {
                mPlayer.reset();
                mPlayer.release();
                mPlayer = null;
            }
            mPlayer = new MediaPlayer();
            try {
                mPlayer.setDataSource(path);
                mPlayer.prepare();
                mPlayer.start();

                WritableMap payload = new WritableNativeMap();
                payload.putString("path", path);
                sendEvent(getReactApplicationContext(), "play_start", payload);

            } catch (IOException e) {
                Log.e(LOG_TAG, "play prepare() failed");

                WritableMap payload = new WritableNativeMap();
                payload.putString("error", "Player initialization failed");
                sendEvent(getReactApplicationContext(), "play_error", payload);
            }
        } else {
            WritableMap payload = new WritableNativeMap();
            payload.putString("error", "Please stop playing previous file before starting new");
            sendEvent(getReactApplicationContext(), "play_error", payload);

        }
    }

    @ReactMethod
    public void pausePlaying() {
        if (mPlayer != null && mPlayer.isPlaying()) {
            try {
                mPlayer.pause();
                WritableMap payload = new WritableNativeMap();
                sendEvent(getReactApplicationContext(), "play_pause", payload);

            } catch (IllegalStateException) {
                WritableMap payload = new WritableNativeMap();
                payload.putString("error", "Cannot pause; Audio engine not initialized");
                sendEvent(getReactApplicationContext(), "play_error", payload);

            }
        }
    }

    @ReactMethod
    public void continuePlaying() {
        if (mPlayer != null && !mPlayer.isPlaying()) {
            try {
                mPlayer.start();
                WritableMap payload = new WritableNativeMap();
                sendEvent(getReactApplicationContext(), "play_continue", payload);

            } catch (IllegalStateException) {
                WritableMap payload = new WritableNativeMap();
                payload.putString("error", "Cannot continue; Audio engine not initialized");
                sendEvent(getReactApplicationContext(), "play_error", payload);

            }
        }
    }

    @ReactMethod
    public void stopPlaying() {
        if (mPlayer != null && mPlayer.isPlaying()) {
            try {
                mPlayer.stop();
            } catch (IllegalStateException e) {
                WritableMap payload = new WritableNativeMap();
                payload.putString("error", "Cannot stop; Audio engine not initialized");
                sendEvent(getReactApplicationContext(), "play_error", payload);
            }
        }
    }

    @Override
    public void onError(MediaRecorder mr, int what, int extra) {
        Log.e(LOG_TAG, "Error during recording: " + what + extra);
        WritableMap payload = new WritableNativeMap();
        payload.putString("error", "Error during recording - what: " + what + " extra: " + extra);
        sendEvent(getReactApplicationContext(), "rec_error", payload);

    }

    @Override
    public void onInfo(MediaRecorder mr, int what, int extra) {
        Log.e(LOG_TAG, "Info about recording: " + what + extra);
        WritableMap payload = new WritableNativeMap();
        payload.putString("info", "Info during recording - what: " + what + " extra: " + extra);
        sendEvent(getReactApplicationContext(), "rec_info", payload);

    }
}
