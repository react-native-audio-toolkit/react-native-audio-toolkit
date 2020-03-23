import { NativeModules, DeviceEventEmitter, NativeAppEventEmitter, Platform } from 'react-native';

import async from 'async';
import EventEmitter from 'eventemitter3';
import MediaStates from './MediaStates';

// Only import specific items from lodash to keep build size down
import filter from 'lodash/filter';
import identity from 'lodash/identity';
import last from 'lodash/last';
import noop from 'lodash/noop';

const RCTAudioPlayer = NativeModules.AudioPlayer;

let playerId = 0;

export const PlaybackCategories = {
  Playback: 1,
  Ambient: 2,
  SoloAmbient: 3,
}

const defaultPlayerOptions = {
  autoDestroy: true,
  continuesToPlayInBackground: false,
  category: PlaybackCategories.Playback,
  mixWithOthers: false,
};

/**
 * Represents a media player
 * @constructor
 */
class Player extends EventEmitter {
  constructor(path, options = defaultPlayerOptions) {
    super();

    this._path = path;

    if (options == null) {
      this._options = defaultPlayerOptions;
    } else {
      // Make sure all required options have values
      if (options.autoDestroy == null)
        options.autoDestroy = defaultPlayerOptions.autoDestroy;
      if (options.continuesToPlayInBackground == null)
        options.continuesToPlayInBackground = defaultPlayerOptions.continuesToPlayInBackground;
      if (options.category == null)
        options.category = defaultPlayerOptions.category;
      if (options.mixWithOthers == null)
        options.mixWithOthers = defaultPlayerOptions.mixWithOthers;

      this._options = options;
    }

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
    const info = last(filter(results, identity));
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

  prepare(callback = noop) {
    this._updateState(null, MediaStates.PREPARING);

    const tasks = [];

    // Prepare player
    tasks.push((next) => {
      RCTAudioPlayer.prepare(this._playerId, this._path, this._options, next);
    });

    // Set initial values for player options
    tasks.push((next) => {
      RCTAudioPlayer.set(
        this._playerId,
        {
          volume: this._volume,
          pan: this._pan,
          wakeLock: this._wakeLock,
          looping: this._looping,
          speed: this._speed,
        },
        next,
      );
    });

    async.series(tasks, (err, results) => {
      this._updateState(err, MediaStates.PREPARED, results);
      callback(err);
    });

    return this;
  }

  play(callback = noop) {
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
      callback(err);
    });

    return this;
  }

  pause(callback = noop) {
    RCTAudioPlayer.pause(this._playerId, (err, results) => {
      // Android emits a pause event on the native side
      if (Platform.OS === 'ios') {
        this._updateState(err, MediaStates.PAUSED, [results]);
      }
      callback(err);
    });

    return this;
  }

  playPause(callback = noop) {
    if (this._state === MediaStates.PLAYING) {
      this.pause((err) => {
        callback(err, true);
      });
    } else {
      this.play((err) => {
        callback(err, false);
      });
    }

    return this;
  }

  stop(callback = noop) {
    RCTAudioPlayer.stop(this._playerId, (err, results) => {
      this._updateState(err, MediaStates.PREPARED);
      this._position = -1;
      callback(err);
    });

    return this;
  }

  destroy(callback = noop) {
    this._reset();
    RCTAudioPlayer.destroy(this._playerId, callback);
  }

  seek(position = 0, callback = noop) {
    // Store old state, but not if it was already SEEKING
    if (this._state != MediaStates.SEEKING) {
      this._preSeekState = this._state;
    }

    this._updateState(null, MediaStates.SEEKING);
    RCTAudioPlayer.seek(this._playerId, position, (err, results) => {
      if (err && err.err === 'seekfail') {
        // Seek operation was cancelled; ignore
        return;
      }

      this._updateState(err, this._preSeekState, [results]);
      callback(err);
    });
  }

  _setIfInitialized(options, callback = noop) {
    if (this._state >= MediaStates.PREPARED) {
      RCTAudioPlayer.set(this._playerId, options, callback);
    }
  }

  set volume(value) {
    this._volume = value;
    this._setIfInitialized({ volume: value });
  }

  set currentTime(value) {
    this.seek(value);
  }

  set wakeLock(value) {
    this._wakeLock = value;
    this._setIfInitialized({ wakeLock: value });
  }

  set looping(value) {
    this._looping = value;
    this._setIfInitialized({ looping: value });
  }

  set speed(value) {
    this._speed = value;
    this._setIfInitialized({ speed: value });
  }

  get currentTime() {
    // Queue up an async call to get an accurate current time
    RCTAudioPlayer.getCurrentTime(this._playerId, (err, results) => {
      this._storeInfo(results);
    });

    if (this._position < 0) {
      return -1;
    }

    if (this._state === MediaStates.PLAYING) {
      // Estimate the current time based on the latest info we received
      let pos = this._position + (Date.now() - this._lastSync) * this._speed;
      pos = Math.min(pos, this._duration);
      return pos;
    }

    return this._position;
  }

  get volume() {
    return this._volume;
  }
  get looping() {
    return this._looping;
  }
  get duration() {
    return this._duration;
  }
  get speed() {
    return this._speed;
  }

  get state() {
    return this._state;
  }
  get canPlay() {
    return this._state >= MediaStates.PREPARED;
  }
  get canStop() {
    return this._state >= MediaStates.PLAYING;
  }
  get canPrepare() {
    return this._state == MediaStates.IDLE;
  }
  get isPlaying() {
    return this._state == MediaStates.PLAYING;
  }
  get isStopped() {
    return this._state <= MediaStates.PREPARED;
  }
  get isPaused() {
    return this._state == MediaStates.PAUSED;
  }
  get isPrepared() {
    return this._state == MediaStates.PREPARED;
  }
}

export default Player;
