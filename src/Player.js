'use strict';

import {
  NativeModules,
  DeviceEventEmitter,
  NativeAppEventEmitter,
  Platform
} from 'react-native';

import _ from 'lodash';
import async from 'async';
import EventEmitter from 'eventemitter3';
import MediaStates from './MediaStates';

var RCTAudioPlayer = NativeModules.AudioPlayer;

var playerId = 0;

var defaultPlayerOptions = {
  autoDestroy: true,
  continuesToPlayInBackground: false
};

/**
 * Represents a media player
 * @constructor
 */
class Player extends EventEmitter {
  constructor(path, options = defaultPlayerOptions) {
    super();

    this._path = path;
    this._options = options;

    this._playerId = playerId++;
    this._reset();

    let appEventEmitter = Platform.OS === 'ios' ? NativeAppEventEmitter : DeviceEventEmitter;

    appEventEmitter.addListener('RCTAudioPlayerEvent:' + this._playerId, (payload: Event) => {
      this._handleEvent(payload.event, payload.data);
    });
  }

  _reset() {
    this._state = MediaStates.IDLE;
    this._volume = 1.0;
    this._pan = 0.0;
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
    let info = _.last(_.filter(results, _.identity));
    this._storeInfo(info);
  }

  _handleEvent(event, data) {
    //console.log('event: ' + event + ', data: ' + JSON.stringify(data));
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
        //this.emit('error', data);
        break;
      case 'pause':
        this._state = MediaStates.PAUSED;
        this._storeInfo(data.info);
        break;
      case 'looped':
        this._position = 0;
        this._lastSync = Date.now();
        break;
    }

    this.emit(event, data);
  }

  prepare(callback = _.noop) {
    this._updateState(null, MediaStates.PREPARING);

    let tasks = [];

    // Prepare player
    tasks.push((next) => {
      RCTAudioPlayer.prepare(this._playerId, this._path, this._options, next);
    });

    // Set initial values for player options
    tasks.push((next) => {
      RCTAudioPlayer.set(this._playerId, {
        volume: this._volume,
        pan: this._pan,
        wakeLock: this._wakeLock,
        looping: this._looping
      }, next);
    });

    async.series(tasks, (err, results) => {
      this._updateState(err, MediaStates.PREPARED, results);
      callback(err);
    });

    return this;
  }

  play(callback = _.noop) {
    let tasks = [];

    // Make sure player is prepared
    if(this._state === MediaStates.IDLE) {
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

  pause(callback = _.noop) {
    RCTAudioPlayer.pause(this._playerId, (err, results) => {
      this._updateState(err, MediaStates.PAUSED, [results]);
      callback(err);
    });

    return this;
  }

  playPause(callback = _.noop) {
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

  stop(callback = _.noop) {
    RCTAudioPlayer.stop(this._playerId, (err, results) => {
      this._updateState(err, MediaStates.PREPARED);
      this._position = -1;
      callback(err);
    });

    return this;
  }

  destroy(callback = _.noop) {
    this._reset();
    RCTAudioPlayer.destroy(this._playerId, callback);
  }

  seek(position = 0, callback = _.noop) {
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

  _setIfInitialized(options, callback = _.noop) {
    if (this._state >= MediaStates.PREPARED) {
      RCTAudioPlayer.set(this._playerId, options, callback);
    }
  }

  set volume(value) {
    this._volume = value;
    this._setIfInitialized({'volume': value});
  }

  set currentTime(value) {
    this.seek(value);
  }

  set wakeLock(value) {
    this._wakeLock = value;
    this._setIfInitialized({'wakeLock': value});
  }

  set looping(value) {
    this._looping = value;
    this._setIfInitialized({'looping': value});
  }

  get currentTime() {
    let pos = -1;

    if (this._position < 0) {
      return -1;
    }

    if (this._state === MediaStates.PLAYING) {
      pos = this._position + (Date.now() - this._lastSync);
      pos = Math.min(pos, this._duration);

      return pos;
    } else {
      return this._position;
    }
  }

  get volume() { return this._volume; }
  get looping() { return this._looping; }
  get duration() { return this._duration; }

  get state()      { return this._state; }
  get canPlay()    { return this._state >= MediaStates.PREPARED; }
  get canStop()    { return this._state >= MediaStates.PLAYING;  }
  get canPrepare() { return this._state == MediaStates.IDLE;     }
  get isPlaying()  { return this._state == MediaStates.PLAYING;  }
  get isStopped()  { return this._state <= MediaStates.PREPARED; }
  get isPaused()   { return this._state == MediaStates.PAUSED;   }
  get isPrepared() { return this._state == MediaStates.PREPARED; }
}

export default Player;
