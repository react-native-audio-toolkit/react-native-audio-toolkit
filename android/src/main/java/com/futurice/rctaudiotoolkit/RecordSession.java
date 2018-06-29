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

    final int id;
    final String path;
    final MediaRecorder recorder;
    final Uri uri;

    boolean autoDestroy = true;

    RecordSession(Context context, Integer recorderId, String path, ReadableMap options) {
        this.id = recorderId;
        this.path = path;
        uri = uriFromPath(context, this.path);

        recorder = new MediaRecorder();
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
        recorder.setOutputFile(uri.getPath());

        if (options.hasKey("autoDestroy")) {
            autoDestroy = options.getBoolean("autoDestroy");
        }

        Log.d(TAG, "Record session created : {" +
                "id=" + id +
                ", path='" + path + '\'' +
                ", autoDestroy=" + autoDestroy +
                ", uri=" + uri.getPath() +
                ", options: " +
                "(format: " + format + ") " +
                "(encoder: " + encoder + ") " +
                "(bitrate: " + bitrate + ") " +
                "(channels: " + channels + ") " +
                "(sampleRate: " + sampleRate + ")" +
                "}");
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

    public void prepare() throws IllegalStateException, IOException {
        recorder.prepare();
        Log.d(TAG, id + ": Prepared");
    }

    public void start() throws IllegalStateException {
        recorder.start();
        Log.d(TAG, id + ": Started");

    }

    public void pause() throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            recorder.pause();
        } else {
            throw new Exception("Pause is not supported under Android 7.0");
        }
        Log.d(TAG, id + ": Paused");
    }

    public void resume() throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            recorder.resume();
        } else {
            throw new Exception("Resume is not supported under Android 7.0");
        }
        Log.d(TAG, id + ": Resumed");
    }

    public void stop() throws IllegalStateException {
        recorder.stop();
        Log.d(TAG, id + ": Stopped");

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
