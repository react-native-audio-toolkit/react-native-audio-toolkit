package com.futurice.rctaudiotoolkit;

import android.content.Context;
import android.content.ContextWrapper;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.webkit.URLUtil;

import com.facebook.react.bridge.ReadableMap;

import java.io.File;
import java.io.IOException;

public class RecordSession {
    private static final String TAG = "RecordSession";
    private static final String TMP_REC_POST_FIX = "_$TEMP$";

    private MediaRecorder recorder;
    private ReadableMap options;

    private MediaRecorder.OnErrorListener errorListener;
    private MediaRecorder.OnInfoListener infoListener;

    private final int id;
    private final String path;

    private Context context;
    private Uri currentRecUri;
    private boolean autoDestroy = true;

    private boolean isPaused = false;

    RecordSession(Context context, Integer recorderId, String path, ReadableMap options) {
        this.context = context;
        this.id = recorderId;
        if (path.endsWith("/")) {
            path = path.substring(0, path.length() - 1);
        }
        this.path = path;
        this.options = options;

        if (options.hasKey("autoDestroy")) {
            autoDestroy = options.getBoolean("autoDestroy");
        }
    }

    private MediaRecorder createRecorder(boolean isMainRecFile) {
        MediaRecorder recorder = new MediaRecorder();
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC);

        int format = parseFormatFromFileExt(this.path);
        int encoder = encoderFromPath(this.path);
        int bitrate = 128000;
        int channels = 2;
        int sampleRate = 44100;

        if (options.hasKey("format")) {
            format = getFormatByName(options.getString("format"));
        }
        if (options.hasKey("encoder")) {
            encoder = getEncoderByName(options.getString("encoder"));
        }
        if (options.hasKey("bitrate")) {
            bitrate = options.getInt("bitrate");
        }
        if (options.hasKey("channels")) {
            channels = options.getInt("channels");
        }
        if (options.hasKey("sampleRate")) {
            sampleRate = options.getInt("sampleRate");
        }

        recorder.setOutputFormat(format);
        recorder.setAudioEncoder(encoder);
        recorder.setAudioEncodingBitRate(bitrate);
        recorder.setAudioChannels(channels);
        recorder.setAudioSamplingRate(sampleRate);

        if (isMainRecFile) {
            currentRecUri = uriFromPath(context, this.path);
        } else {
            currentRecUri = uriFromPath(context, this.path + TMP_REC_POST_FIX);
        }
        recorder.setOutputFile(currentRecUri.getPath());

        recorder.setOnErrorListener(errorListener);
        recorder.setOnInfoListener(infoListener);

        Log.d(TAG, "Recorder created : {" +
                "id=" + id +
                ", path='" + path + '\'' +
                ", autoDestroy=" + autoDestroy +
                ", currentRecUri=" + currentRecUri.getPath() +
                ", options: " +
                "(format: " + format + ") " +
                "(encoder: " + encoder + ") " +
                "(bitrate: " + bitrate + ") " +
                "(channels: " + channels + ") " +
                "(sampleRate: " + sampleRate + ")" +
                "}");

        return recorder;
    }

    private int encoderFromPath(String path) {
        String ext = path.substring(path.lastIndexOf('.') + 1);

        return getEncoderByName(ext);
    }

    private Uri uriFromPath(Context context, String path) {
        if (URLUtil.isValidUrl(path)) {
            return Uri.parse(path);
        } else {
            String extPath = new ContextWrapper(context).getFilesDir() + "/" + path;
            File file = new File(extPath);
            return Uri.fromFile(file);
        }
    }

    void appendFileIfResumed() {
        if (currentRecUri.getPath().endsWith(TMP_REC_POST_FIX)) {
            String mainRecordFile = uriFromPath(context, path).getPath();
            Mp4Util.append(mainRecordFile, currentRecUri.getPath());
        }
    }

    private int parseFormatFromFileExt(String path) {
        String ext = path.substring(path.lastIndexOf('.') + 1);
        return getFormatByName(ext);
    }

    private int getFormatByName(String name) {
        switch (name) {
            case "aac":
                return MediaRecorder.OutputFormat.AAC_ADTS;
            case "mp4":
                return MediaRecorder.OutputFormat.MPEG_4;
            case "webm":
            case "ogg":
                return MediaRecorder.OutputFormat.WEBM;
            case "amr":
                return MediaRecorder.OutputFormat.AMR_WB;
            default:
                Log.e(TAG, "Format with name " + name + " not found.");
                return MediaRecorder.OutputFormat.DEFAULT;
        }
    }

    private int getEncoderByName(String name) {
        switch (name) {
            case "aac":
                return MediaRecorder.AudioEncoder.AAC;
            case "mp4":
                return MediaRecorder.AudioEncoder.HE_AAC;
            case "webm":
            case "ogg":
                return MediaRecorder.AudioEncoder.VORBIS;
            case "amr":
                return MediaRecorder.AudioEncoder.AMR_WB;
            default:
                Log.e(TAG, "Encoder with name " + name + " not found.");
                return MediaRecorder.AudioEncoder.DEFAULT;
        }
    }

    public MediaRecorder getRecorder() {
        return recorder;
    }

    public int getId() {
        return id;
    }

    public String getUriPath() {
        return currentRecUri.getPath();
    }

    public void setOnErrorListener(MediaRecorder.OnErrorListener listener) {
        this.errorListener = listener;
    }

    public void setOnInfoListener(MediaRecorder.OnInfoListener listener) {
        this.infoListener = listener;
    }

    public void prepare() throws IllegalStateException, IOException {
        recorder = createRecorder(true);
        recorder.prepare();
        Log.d(TAG, id + ": Prepared");
    }

    public void start() throws IllegalStateException {
        recorder.start();
        Log.d(TAG, id + ": Started");
    }

    public void resume() throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            recorder.resume();
        } else if (isPaused) {
            isPaused = false;
            recorder = createRecorder(false);
            recorder.prepare();
            recorder.start();
        }
        Log.d(TAG, id + ": Resumed");
    }

    public void pause() throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            recorder.pause();
        } else if (!isPaused) {
            isPaused = true;
            recorder.stop();
            recorder.release();
            recorder = null;

            appendFileIfResumed();
        }
        Log.d(TAG, id + ": Paused");
    }

    public void stop() throws IllegalStateException {
        recorder.stop();
        Log.d(TAG, id + ": Stopped");

        appendFileIfResumed();

        if (autoDestroy) {
            Log.d(TAG, "Auto destroying recorder...");
            destroy();
        }
    }

    public void destroy() {
        recorder.release();
        Log.d(TAG, id + ": Destroyed.");
    }
}
