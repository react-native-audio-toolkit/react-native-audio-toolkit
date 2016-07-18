'use strict';

import { NativeModules } from 'react-native';
import { _ } from 'lodash';
import * as async from 'async';

var RCTAudioPlayer = NativeModules.AudioPlayer;
var RCTAudioRecorder = NativeModules.AudioRecorder;

var playerId = 0;

var states = {
  ERROR: -1,
  IDLE: 0,
  INITIALIZING: 1,
  INITIALIZED: 2,
  PREPARING: 3,
  PREPARED: 4,
  PLAYING: 5,
  PAUSED: 6
};

class Player {
  constructor(path) {
    this._path = path;

    this._playerId = playerId++;
    this._reset();
  }

  _reset() {
    this._state = states.IDLE;
    this._volume = 1.0;
    this._pan = 0.0;
    this._wakeLock = false;
    this._autoDestroy = true;
    this._duration = -1;
    this._position = -1;
    this._lastSync = -1;
  }

  _storeInfo(info) {
    this._duration = info.duration;
    this._position = info.position;
    this._lastSync = Date.now();
  }

  _updateState(err, state, results) {
    this._state = err ? states.ERROR : state;

    if (err || !results) {
      return;
    }

    // Use last truthy value from results array as new media info
    let info = _.last(_.filter(results, _.identity));
    this._storeInfo(info);
  }

  init(callback = _.noop) {
    if (this._state != states.IDLE) {
      this._reset();
    }

    this._updateState(null, states.INITIALIZING);

    async.series([
      // Initialize the player
      (next) => {
        RCTAudioPlayer.init(this._playerId, this._path, next);
      },

      // Set initial values for player options
      (next) => {
        RCTAudioPlayer.set(this._playerId, {
          volume: this._volume,
          pan: this._pan,
          wakeLock: this._wakeLock,
          autoDestroy: this._autoDestroy
        }, next);
      }
    ],

    (err, results) => {
      _updateState(err, states.INITIALIZED);
      callback(err);
    });
  }

  prepare(position = -1, callback = _.noop) {
    if (typeof position === 'function') {
      callback = position;
      position = -1;
    }

    let tasks = [];

    // Initialize player if not initialized yet
    if (this._state < states.INITIALIZED) {
      tasks.push(this.init.bind(this));
    }

    // Prepare player if not prepared yet
    if (this._state < states.PREPARED) {
      tasks.push((next) => {
        RCTAudioPlayer.prepare(this._playerId, next);
      });
    }

    // Seek to position if given
    if (position != -1) {
      tasks.push((next) => {
        RCTAudioPlayer.seek(this._playerId, position, next);
      });
    }

    async.series(tasks, (err, results) => {
      this._updateState(err, states.PREPARED, results);
      callback(err);
    });

    return this;
  }

  play(position = 0, callback = _.noop) {
    if (typeof position === 'function') {
      callback = position;
      position = 0;
    }

    async.series([
      // Make sure player is prepared
      (next) => {
        this.prepare(position, next);
      },

      // Start playback
      (next) => {
        RCTAudioPlayer.play(this._playerId, next);
      }
    ],

    (err, results) => {
      this._updateState(err, states.PLAYING, results);
      callback(err);
    });

    return this;
  }

  resume(callback = _.noop) {
    this.play(-1, callback);
  }

  pause(callback = _.noop) {
    RCTAudioPlayer.pause(this._playerId, (err) => {
      this._updateState(err, states.PAUSED);
      callback(err);
    });
    return this;
  }

  stop(callback = _.noop) {
    RCTAudioPlayer.stop(this._playerId, (err) => {
      this._updateState(err, states.INITIALIZED);
      this._position = -1;
      callback(err);
    });
    return this;
  }

  destroy(callback = _.noop) {
    this._reset();
    RCTAudioPlayer.destroy(this._playerId);
  }

  get volume() {
    return this._volume;
  }

  set volume(volume) {
    this._volume = volume;

    if (this._state >= states.INITIALIZED) {
      RCTAudioPlayer.set(this._playerId, {'volume': this._volume}, _.noop);
    }
  }

  set wakeLock(value) {
    this._wakeLock = value;

    if (this._state >= states.INITIALIZED) {
      RCTAudioPlayer.set(this._playerId, {'wakeLock': this._wakeLock}, _.noop);
    }
  }

  set autoDestroy(value) {
    this._autoDestroy = value;

    if (this._state >= states.INITIALIZED) {
      RCTAudioPlayer.set(this._playerId, {'autoDestroy': this._autoDestroy});
    }
  }

  get duration() {
    return this._duration;
  }

  get currentTime() {
    let pos = -1;

    if (this._position < 0) {
      return -1;
    }

    if (this._state === states.PLAYING) {
      pos = this._position + (Date.now() - this._lastSync);
      pos = Math.min(pos, this._duration);

      pos /= 1000;

      return pos;
    } else {
      return this._position / 1000;
    }
  }

  set currentTime(value) {
    // TODO: this always causes media to play even without user calling play()
    this.play(value * 1000);
  }
}

export { Player };
