import EventEmitter from 'eventemitter3';

// IMPORTANT: If you change anything in this file, make sure to also update: react-native-audio-toolkit/docs/API.md

declare enum MediaStates {
    DESTROYED = -2,
    ERROR = -1,
    IDLE = 0,
    PREPARING = 1,
    PREPARED = 2,
    SEEKING = 3,
    PLAYING = 4,
    RECORDING = 4,
    PAUSED = 5
}

declare enum PlaybackCategories {
    Playback = 1,
    Ambient = 2,
    SoloAmbient = 3,
}

interface BaseError<T> {
    err: "invalidpath" | "preparefail" | "startfail" | "notfound" | "stopfail" | T;
    message: string;
    stackTrace: string[] | string;
}
/**
 * For more details, see:
 * https://github.com/react-native-community/react-native-audio-toolkit/blob/master/docs/API.md#user-content-callbacks
 */
export type PlayerError = BaseError<"seekfail">;

/**
 * For more details, see:
 * https://github.com/react-native-community/react-native-audio-toolkit/blob/master/docs/API.md#user-content-callbacks
 */
export type RecorderError = BaseError<"notsupported">;

interface PlayerOptions {
    /**
     * Boolean to indicate whether the player should self-destruct after playback is finished.
     * If this is not set, you are responsible for destroying the object by calling `destroy()`.
     * (Default: true)
     */
    autoDestroy?: boolean;

    /**
     * (Android only) Should playback continue if app is sent to background?
     * iOS will always pause in this case.
     * (Default: false)
     */
    continuesToPlayInBackground?: boolean;

    /**
     * (iOS only) Define the audio session category
     * (Default: Playback)
     */
    category?: PlaybackCategories;

    /**
     * Boolean to determine whether other audio sources on the device will mix
     * with sounds being played back by this module.
     * (Default: false)
     */
    mixWithOthers?: boolean;
}

/**
 * Represents a media player
 */
declare class Player extends EventEmitter {
    /**
     * Initialize the player for playback of song in path.
     * 
     * @param path Path can be either filename, network URL or a file URL to resource.
     * @param options 
     */
    constructor(path: string, options?: PlayerOptions);

    /**
     * Prepare playback of the file provided during initialization. This method is optional to call but might be
     * useful to preload the file so that the file starts playing immediately when calling `play()`.
     * Otherwise the file is prepared when calling `play()` which may result in a small delay.
     * 
     * @param callback Callback is called with empty first parameter when file is ready for playback with `play()`.
     */
    prepare(callback?: ((err: PlayerError | null) => void)): this;

    /**
     * Start playback.
     * 
     * @param callback If callback is given, it is called when playback has started.
     */
    play(callback?: ((err: PlayerError | null) => void)): this;

    /**
     * Pauses playback. Playback can be resumed by calling `play()` with no parameters.
     * 
     * @param callback Callback is called after the operation has finished.
     */
    pause(callback?: ((err: PlayerError | null) => void)): this;

    /**
     * Helper method for toggling pause.
     * 
     * @param callback Callback is called after the operation has finished. Callback receives Object error as first
     * argument, Boolean paused as second argument indicating if the player ended up playing (`false`)
     * or paused (`true`).
     */
    playPause(callback?: ((err: PlayerError | null, paused: boolean) => void)): this;

    /**
     * Stop playback. If autoDestroy option was set during initialization, clears all media resources from memory.
     * In this case the player should no longer be used.
     * 
     * @param callback 
     */
    stop(callback?: ((err: PlayerError | null) => void)): this;

    /**
     * Stops playback and destroys the player. The player should no longer be used.
     * 
     * @param callback Callback is called after the operation has finished.
     */
    destroy(callback?: ((err: PlayerError | null) => void)): void;

    /**
     * Seek in currently playing media.
     * 
     * @param position Position is the offset from the start.
     * @param callback If callback is given, it is called when the seek operation completes. If another seek
     * operation is performed before the previous has finished, the previous operation gets an error in its
     * callback with the err field set to oldcallback. The previous operation should likely do nothing in this case.
     */
    seek(position?: number, callback?: ((err: PlayerError | null) => void)): void;

    /**
     * Get/set playback volume. The scale is from 0.0 (silence) to 1.0 (full volume). Default is 1.0.
     */
    volume: number;

    /**
     * Get/set current playback position in milliseconds. It's recommended to do seeking via `seek()`,
     * as it is not possible to pass a callback when setting the `currentTime` property.
     */
    currentTime: number;

    /**
     * Get/set wakeLock on player, keeping it alive in the background. Default is `false`. Android only.
     */
    wakeLock: boolean;

    /**
     * Get/set looping status of the current file. If `true`, file will loop when playback reaches end of file.
     * Default is `false`.
     */
    looping: boolean;

    /**
     * Get/set the playback speed for audio.
     * Default is `1.0`.
     * 
     * NOTE: On Android, this is only supported on Android 6.0+.
     */
    speed: number;

    /**
     * Get duration of prepared/playing media in milliseconds.
     * If no duration is available (for example live streams), `-1` is returned.
     */
    readonly duration: number;

    /**
     * Get the playback state.
     */
    readonly state: MediaStates;

    /**
     * `true` if player can begin playback.
     */
    readonly canPlay: boolean;

    /**
     * `true` if player can stop playback.
     */
    readonly canStop: boolean;

    /**
     * `true` if player can prepare for playback.
     */
    readonly canPrepare: boolean;

    /**
     * `true` if player is playing.
     */
    readonly isPlaying: boolean;

    /**
     * `true` if player is stopped.
     */
    readonly isStopped: boolean;

    /**
     * `true` if player is paused.
     */
    readonly isPaused: boolean;

    /**
     * `true` if player is prepared.
     */
    readonly isPrepared: boolean;
}

interface RecorderOptions {
    /**
     * Set bitrate for the recorder, in bits per second (Default: 128000)
     */
    bitrate: number;

    /**
     * Set number of channels (Default: 2)
     */
    channels: number;

    /**
     * Set how many samples per second (Default: 44100)
     */
    sampleRate: number;

    /**
     * Override format. Possible values:
     *   - Cross-platform:  'mp4', 'aac'
     *   - Android only:    'ogg', 'webm', 'amr'
     * 
     * (Default: based on filename extension)
     */
    format: string;

    /**
     * Override encoder. Android only.
     * 
     * Possible values: 'aac', 'mp4', 'webm', 'ogg', 'amr'
     * 
     * (Default: based on filename extension)
     */
    encoder: string;

    /**
     * Quality of the recording, iOS only.
     * 
     * Possible values: 'min', 'low', 'medium', 'high', 'max'
     * 
     * (Default: 'medium')
     */
    quality: string;
}

/**
 * Represents a media recorder
 */
declare class Recorder extends EventEmitter {
    /**
     * Initialize the recorder for recording to file in `path`.
     * 
     * @param path Path can either be a filename or a file URL (Android only).
     * @param options 
     */
    constructor(path: string, options?: RecorderOptions);

    /**
     * Prepare recording to the file provided during initialization. This method is optional to call but it may be
     * beneficial to call to make sure that recording begins immediately after calling `record()`. Otherwise the
     * recording is prepared when calling `record()` which may result in a small delay.
     * 
     * NOTE: Assume that this wipes the destination file immediately.
     * 
     * @param callback When ready to record using `record()`, the callback is called with an empty first parameter.
     * Second parameter contains a path to the destination file on the filesystem.
     * 
     * If there was an error, the callback is called with an error object as first parameter.
     */
    prepare(callback?: ((err: RecorderError | null, fsPath: string) => void)): this;

    /**
     * Start recording to file in `path`.
     * 
     * @param callback Callback is called after recording has started or with error object if an error occurred.
     */
    record(callback?: ((err: RecorderError | null) => void)): this;

    /**
     * Stop recording and save the file.
     * 
     * @param callback Callback is called after recording has stopped or with error object.
     * The recorder is destroyed after calling stop and should no longer be used.
     */
    stop(callback?: ((err: RecorderError | null) => void)): this;

    /**
     * 
     * @param callback 
     */
    pause(callback?: ((err: RecorderError | null) => void)): this;

    /**
     * 
     * @param callback 
     */
    toggleRecord(callback?: ((err: RecorderError | null) => void)): this;

    /**
     * Destroy the recorder. Should only be used if a recorder was constructed, and for some reason is now unwanted.
     * 
     * @param callback Callback is called after the operation has finished.
     */
    destroy(callback?: ((err: RecorderError | null) => void)): void;

    /**
     * Get the filesystem path of file being recorded to.
     * Available after `prepare()` call has invoked its callback successfully.
     */
    readonly fsPath: string;

    /**
     * Get the recording state.
     */
    readonly state: MediaStates;

    /**
     * `true` if recorder can begin recording.
     */
    readonly canRecord: boolean;

    /**
     * `true` if recorder can prepare for recording.
     */
    readonly canPrepare: boolean;

    /**
     * `true` if recorder is recording.
     */
    readonly isRecording: boolean;

    /**
     * `true` if recorder is prepared.
     */
    readonly isPrepared: boolean;
}

export { Player, Recorder, MediaStates };
