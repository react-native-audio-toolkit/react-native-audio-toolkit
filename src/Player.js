//@flow
import {DeviceEventEmitter, NativeAppEventEmitter, NativeModules, Platform} from 'react-native';

import _ from 'lodash';
import async from 'async';
import EventEmitter from 'eventemitter3';
import type {MediaStateType} from "./MediaStates";
import MediaStates from './MediaStates';
import type {Callback, CallbackWithBoolean,} from "./TypeDefs";

const RCTAudioPlayer = NativeModules.AudioPlayer;
type PlayerID = number;
let playerId: PlayerID = 0;

type PlayerOptions = {
  /**
   * Boolean to indicate whether the player should self-destruct after
   * playback is finished. If this is not set, you are responsible for
   * destroying the object by calling player.destroy().
   * default: True
   */
  autoDestroy?: boolean,

  /** (Android only) Should playback continue if app is sent to background?
   * iOS will always pause in this case.
   * default: False
   */
  continuesToPlayInBackground?: boolean,
};

const defaultPlayerOptions = {
  autoDestroy: true,
  continuesToPlayInBackground: false,
};

/**
 * Represents a media player
 * @constructor
 */
export default class Player extends EventEmitter {
  _path: string;
  _options: PlayerOptions;
  _playerId: PlayerID;
  _state: MediaStateType;
  _volume: number;
  _pan: number;
  _speed: number;
  _pitch: number;
  _wakeLock: boolean;
  _duration: number;
  _position: number;
  _lastSync: number;
  _looping: boolean;
  _preSeekState: MediaStateType;

  static precacheItem = (uri: string,
                         options: any,
                         callback: (isSuccess: boolean, message: string) => any) => {
    if (Platform.OS === "android") {
      RCTAudioPlayer.precacheItem(uri, options, callback);
    } else {
      callback(false, "Cache is only supported on Android");
    }
  };

  constructor(path: string, options: PlayerOptions = defaultPlayerOptions) {
    super();
    this._path = path;
    this._options = options;
    this._playerId = playerId++;

    this._reset();

    const appEventEmitter = Platform.OS === 'ios' ? NativeAppEventEmitter : DeviceEventEmitter;
    appEventEmitter.addListener(`RCTAudioPlayerEvent:${this._playerId}`, (payload: Event) => {
      this._handleEvent(payload.event, payload.data);
    });
  }

  _reset() {
    this._state = MediaStates.IDLE;
    this._volume = 1.0;
    this._pan = 0.0;
    this._speed = 1.0;
    this._pitch = 1.0;
    this._wakeLock = false;
    this._duration = -1;
    this._position = -1;
    this._lastSync = -1;
    this._looping = false;
  }

  _storeInfo(info) {
    if (!info) {
      return;
    }

    this._duration = info.duration;
    this._position = info.position;
    this._lastSync = Date.now();
  }

  _updateState(err, state, results) {
    this._state = err ? MediaStates.ERROR : state;

    if (err || !results) {
      return;
    }

    // Use last truthy value from results array as new media info
    const info = _.last(_.filter(results, _.identity));
    this._storeInfo(info);
  }

  _handleEvent(event, data) {
    // console.log('event: ' + event + ', data: ' + JSON.stringify(data));
    switch (event) {
      case 'progress':
        // TODO
        break;
      case 'ended':
        this._updateState(null, MediaStates.PREPARED);
        this._position = -1;
        break;
      case 'info':
        // TODO
        break;
      case 'error':
        this._state = MediaStates.ERROR;
        // this.emit('error', data);
        break;
      case 'pause':
        this._state = MediaStates.PAUSED;
        this._storeInfo(data.info);
        break;
      case 'forcePause':
        this.pause();
        break;
      case 'looped':
        this._position = 0;
        this._lastSync = Date.now();
        break;
    }

    this.emit(event, data);
  }

  /**
   * Prepare playback of the file provided during initialization.
   * This method is optional to call but might be useful to preload the file
   * so that the file starts playing immediately when calling play().
   * Otherwise the file is prepared when calling play() which may result in a small delay.
   *
   * @param callback
   * @return Promise<void>
   */
  prepare(callback?: Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      this._updateState(null, MediaStates.PREPARING);

      const tasks = [];

      // Prepare player
      tasks.push((next) => RCTAudioPlayer.prepare(this._playerId, this._path, this._options, next));

      // Set initial values for player options
      tasks.push((next) => {
        RCTAudioPlayer.set(
          this._playerId,
          {
            volume: this._volume,
            pan: this._pan,
            wakeLock: this._wakeLock,
            looping: this._looping,

            // FIXME Speed or pitch make auto play on Android when the sound source is remote URL
            speed: this._speed,
            pitch: this._pitch,
          },
          next,
        );
      });

      async.series(tasks, (err, results) => {
        this._updateState(err, MediaStates.PREPARED, results);
        err ? reject(err) : resolve();
      });
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   * Start playback.
   *
   * @param callback
   * @return Promise<void>
   */
  play(callback?: Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      const tasks = [];

      // Make sure player is prepared
      if (this._state === MediaStates.IDLE) {
        tasks.push((next) => {
          this.prepare(next);
        });
      }

      // Start playback
      tasks.push((next) => {
        RCTAudioPlayer.play(this._playerId, next);
      });

      async.series(tasks, (err, results) => {
        this._updateState(err, MediaStates.PLAYING, results);
        err ? reject(err) : resolve();
      });
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }


  /**
   * Pauses playback. Playback can be resumed by calling play()
   *
   * @param callback
   * @return Promise<void>
   */
  pause(callback?: Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      RCTAudioPlayer.pause(this._playerId, (err, results) => {
        if (Platform.OS === 'ios') {
          this._updateState(err, MediaStates.PAUSED, [results]);
        } else {
          // Android emits a pause event on the native side
        }
        err ? reject(err) : resolve();
      });
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   * Helper method for toggling pause.
   * Callback is called after the operation has finished.
   *
   * @param callback
   * @return Promise<boolean> playing (true) or paused (false).
   */
  playPause(callback?: CallbackWithBoolean): Promise<boolean> {
    const promise = new Promise((resolve, reject) => {
      if (this._state === MediaStates.PLAYING) {
        this.pause(err => err ? reject(err) : resolve(true));
      } else {
        this.play(err => err ? reject(err) : resolve(false));
      }
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   * Stop playback.
   *
   * If autoDestroy option was set during initialization,
   * clears all media resources from memory.
   * In this case the player should no longer be used.
   *
   * @param callback
   * @return {any}
   */
  stop(callback?: Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      RCTAudioPlayer.stop(this._playerId, err => {
        this._updateState(err, MediaStates.PREPARED);
        this._position = -1;
        err ? reject(err) : resolve();
      });
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   *Stops playback and destroys the player.
   * The player should no longer be used.
   *
   * @param callback
   * @return Promise<void>
   */
  destroy(callback?: Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      this._reset();
      RCTAudioPlayer.destroy(this._playerId, err => err ? reject(err) : resolve());
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   * Seek in currently playing media. position is the offset from the start.
   *
   * If callback is given, it is called when the seek operation completes.
   * If another seek operation is performed before the previous has finished,
   * the previous operation gets an error in its callback with the err field set to oldcallback.
   * The previous operation should likely do nothing in this case.
   *
   * @param position
   * @param callback
   * @return {any}
   */
  seek(position: number = 0, callback ?: Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      // Store old state, but not if it was already SEEKING
      if (this._state !== MediaStates.SEEKING) {
        this._preSeekState = this._state;
      }

      this._updateState(null, MediaStates.SEEKING);
      RCTAudioPlayer.seek(this._playerId, position, (err, results) => {
        if (err && err.err === 'seekfail') {
          // Seek operation was cancelled; ignore
          return;
        }

        this._updateState(err, this._preSeekState, [results]);
        err ? reject(err) : resolve();
      });
    });
    return !callback ? promise : promise.then(callback).catch(callback);
  }

  _setIfInitialized(options, callback = _.noop) {
    if (this._state >= MediaStates.PREPARED) {
      RCTAudioPlayer.set(this._playerId, options, callback);
    }
  }

  set volume(value: number) {
    this._volume = value;
    this._setIfInitialized({volume: value});
  }

  set currentTime(value: number) {
    this.seek(value);
  }

  set wakeLock(value: boolean) {
    this._wakeLock = value;
    this._setIfInitialized({wakeLock: value});
  }

  set looping(value: boolean) {
    this._looping = value;
    this._setIfInitialized({looping: value});
  }

  set pitch(value: number) {
    this._pitch = value;
    this._setIfInitialized({pitch: value});
  }

  set speed(value: number) {
    this._speed = value;
    this._setIfInitialized({speed: value});
  }

  get currentTime(): number {
    let pos = -1;

    if (this._position < 0) {
      return -1;
    }

    if (this._state === MediaStates.PLAYING) {
      pos = this._position + (Date.now() - this._lastSync);
      pos = Math.min(pos, this._duration);

      return pos;
    }
    return this._position;
  }

  get volume(): number {
    return this._volume;
  }

  get looping(): boolean {
    return this._looping;
  }

  get duration(): number {
    return this._duration;
  }

  get speed(): number {
    return this._speed;
  }

  get pitch(): number {
    return this._pitch;
  }

  get state(): MediaStateType {
    return this._state;
  }

  get canPlay(): boolean {
    return this._state >= MediaStates.PREPARED;
  }

  get canStop(): boolean {
    return this._state >= MediaStates.PLAYING;
  }

  get canPrepare(): boolean {
    return this._state === MediaStates.IDLE;
  }

  get isPlaying(): boolean {
    return this._state === MediaStates.PLAYING;
  }

  get isStopped(): boolean {
    return this._state <= MediaStates.PREPARED;
  }

  get isPaused(): boolean {
    return this._state === MediaStates.PAUSED;
  }

  get isPrepared(): boolean {
    return this._state === MediaStates.PREPARED;
  }
}


