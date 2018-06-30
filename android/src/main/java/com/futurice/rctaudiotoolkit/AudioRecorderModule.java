package com.futurice.rctaudiotoolkit;

import android.media.MediaRecorder;
import android.text.TextUtils;
import android.util.Log;
import android.util.SparseArray;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.io.IOException;
import java.util.Objects;

public class AudioRecorderModule extends ReactContextBaseJavaModule implements
        MediaRecorder.OnInfoListener, MediaRecorder.OnErrorListener {

    private static final String LOG_TAG = "AudioRecorderModule";

    private static final Callback NOP = new Callback() {
        @Override
        public void invoke(Object... args) {
            // Do nothing
        }
    };

    private SparseArray<RecordSession> sessionPool = new SparseArray<>();
    private ReactApplicationContext context;

    public AudioRecorderModule(ReactApplicationContext reactContext) {
        super(reactContext);
        context = reactContext;
    }

    @Override
    public String getName() {
        return "RCTAudioRecorder";
    }

    @Override
    public void onInfo(MediaRecorder recorder, int what, int extra) {
        // TODO: translate these codes into english
        WritableMap info = new WritableNativeMap();
        info.putInt("what", what);
        info.putInt("extra", extra);

        WritableMap data = new WritableNativeMap();
        data.putMap("info", info);
        data.putString("message", "Android MediaRecorder info");

        emitEvent(getRecorderId(recorder), "info", data);
    }

    @Override
    public void onError(MediaRecorder recorder, int what, int extra) {
        // TODO: translate these codes into english
        WritableMap err = new WritableNativeMap();
        err.putInt("what", what);
        err.putInt("extra", extra);

        WritableMap data = new WritableNativeMap();
        data.putMap("err", err);
        data.putString("message", "Android MediaRecorder error");

        Integer recorderId = getRecorderId(recorder);
        emitEvent(recorderId, "error", data);
        destroy(recorderId, NOP);
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

    private void emitEvent(Integer recorderId, String event, WritableMap data) {
        WritableMap payload = new WritableNativeMap();
        payload.putString("event", event);
        payload.putMap("data", data);

        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("RCTAudioRecorderEvent:" + recorderId, payload);
    }

    /**
     * Find recorderSession matching recorder from sessionPool
     *
     * @param recorder
     * @return
     */
    private Integer getRecorderId(MediaRecorder recorder) {
        for (int i = 0; i < sessionPool.size(); i++) {
            RecordSession session = sessionPool.valueAt(i);
            if (Objects.equals(recorder, session.getRecorder())) {
                return sessionPool.keyAt(i);
            }
        }
        return null;
    }

    @ReactMethod
    public void prepare(Integer recorderId, String path, ReadableMap options, Callback callback) {
        if (TextUtils.isEmpty(path)) {
            callback.invoke(errObj("invalidpath", "Provided path was empty"));
            return;
        }

        // Release old recorder if exists
        RecordSession oldSession = sessionPool.get(recorderId);
        if (oldSession != null) {
            Log.d(LOG_TAG, "Releasing old recorder session...");
            destroy(oldSession.getId(), NOP);
        }

        RecordSession session = new RecordSession(context, recorderId, path, options);
        session.setOnErrorListener(this);
        session.setOnInfoListener(this);
        sessionPool.put(recorderId, session);

        try {
            session.prepare();
            callback.invoke(null, session.getUriPath());
        } catch (IOException e) {
            Log.e(LOG_TAG, "failed to prepare", e);
            callback.invoke(errObj("preparefail", e.toString()));
        }
    }

    @ReactMethod
    public void record(Integer recorderId, Callback callback) {
        RecordSession recorder = sessionPool.get(recorderId);
        if (recorder == null) {
            callback.invoke(errObj("notfound", "recorderId " + recorderId + "not found."));
            return;
        }

        try {
            recorder.start();
            callback.invoke();
        } catch (Exception e) {
            Log.e(LOG_TAG, "failed to start", e);
            callback.invoke(errObj("startfail", e.toString()));
        }
    }

    @ReactMethod
    public void pause(Integer recorderId, Callback callback) {
        RecordSession recorder = sessionPool.get(recorderId);
        if (recorder == null) {
            callback.invoke(errObj("notfound", "recorderId " + recorderId + "not found."));
            return;
        }

        try {
            recorder.pause();
            callback.invoke();
        } catch (Exception e) {
            Log.e(LOG_TAG, "Failed to pause", e);
            callback.invoke(errObj("pausefail", e.toString()));
            return;
        }
    }

    @ReactMethod
    public void resume(Integer recorderId, Callback callback) {
        RecordSession recorder = sessionPool.get(recorderId);
        if (recorder == null) {
            callback.invoke(errObj("notfound", "recorderId " + recorderId + "not found."));
            return;
        }

        try {
            recorder.resume();
            callback.invoke();
        } catch (Exception e) {
            Log.e(LOG_TAG, "Failed to resume", e);
            callback.invoke(errObj("resumefail", e.toString()));
        }
    }

    @ReactMethod
    public void stop(Integer recorderId, Callback callback) {
        RecordSession recorder = sessionPool.get(recorderId);
        if (recorder == null) {
            callback.invoke(errObj("notfound", "recorderId " + recorderId + "not found."));
            return;
        }

        try {
            recorder.stop();
            callback.invoke();
        } catch (Exception e) {
            Log.e(LOG_TAG, "Failed to stop", e);
            callback.invoke(errObj("stopfail", e.toString()));
        }
    }

    @ReactMethod
    public void destroy(Integer recorderId, Callback callback) {
        RecordSession session = sessionPool.get(recorderId);
        if (session == null) {
            callback.invoke(errObj("notfound", "recorderId " + recorderId + "not found."));
            return;
        }

        session.destroy();
        sessionPool.remove(recorderId);

        WritableMap data = new WritableNativeMap();
        data.putString("message", "Destroyed recorder");
        emitEvent(recorderId, "info", data);

        callback.invoke();
    }
}
