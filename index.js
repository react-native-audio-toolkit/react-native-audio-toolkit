'use strict';

import { NativeModules } from 'react-native';
import { _ } from 'lodash';

var RCTAudioPlayer = NativeModules.AudioPlayer;
var RCTAudioRecorder = NativeModules.AudioRecorder;

var playerId = 0;

var states = {
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

  init(callback = _.noop) {
    if (this._state != states.IDLE) {
      this._reset();
    }

    this._state = states.INITIALIZING;
    RCTAudioPlayer.init(this._playerId, this._path, (err) => {
      if (err) {
        return callback(err);
      }

      RCTAudioPlayer.set(this._playerId, {
        volume: this._volume,
        pan: this._pan,
        wakeLock: this._wakeLock,
        autoDestroy: this._autoDestroy
      }, (err) => {
        if (err) {
          return callback(err);
        }

        this._state = states.INITIALIZED;
        callback();
      });
    });
  }

  prepare(callback = _.noop) {
    // Initialize player if not initialized yet
    if (this._state < states.INITIALIZED) {
      this.init((err) => {
        if (err) {
          return callback(err);
        }

        this.prepare(callback);
      });
    } else {
      this._state = states.PREPARING;
      RCTAudioPlayer.prepare(this._playerId, (err, info) => {
        if (err) {
          return callback(err);
        }

        this._duration = info.duration;
        this._position = info.position;
        this._lastSync = Date.now();

        this._state = states.PREPARED;
        callback();
      });
    }

    return this;
  }

  play(position = 0, callback = _.noop) {
    // Prepare player if not prepared yet
    if (this._state < states.PREPARED) {
      this.prepare((err) => {
        if (err) {
          return callback(err);
        }

        this.play(position, callback);
      });
    } else {
      RCTAudioPlayer.play(this._playerId, position, (err, info) => {
        if (err) {
          return callback(err);
        }

        this._state = states.PLAYING;
        this._duration = info.duration;
        this._position = info.position;
        this._lastSync = Date.now();

        callback();
      });
    }

    return this;
  }

  resume(callback = _.noop) {
    this.play(-1, callback);
  }

  pause(callback = _.noop) {
    RCTAudioPlayer.pause(this._playerId, (err) => {
      if (err) {
        return callback(err);
      }

      this._state = states.PAUSED;
    });
    return this;
  }

  stop(callback = _.noop) {
    RCTAudioPlayer.stop(this._playerId, (err) => {
      if (err) {
        return callback(err);
      }

      this._state = states.INITIALIZED;
      this._position = -1;
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
    var pos = -1;

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
