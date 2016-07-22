'use strict';

import {
  NativeModules,
  DeviceEventEmitter
} from 'react-native';

import _ from 'lodash';
import async from 'async';
import EventEmitter from 'eventemitter3';

var RCTAudioPlayer = NativeModules.AudioPlayer;
var RCTAudioRecorder = NativeModules.AudioRecorder;

var playerId = 0;
var recorderId = 0;

var MediaStates = {
  DESTROYED: -2,
  ERROR: -1,
  IDLE: 0,
  PREPARING: 1,
  PREPARED: 2,
  SEEKING: 3,
  PLAYING: 4,
  RECORDING: 4,
  PAUSED: 5
};

var defaultRecorderOptions = {
  autoDestroy: true
};

var defaultPlayerOptions = {
  autoDestroy: true
};

class Recorder extends EventEmitter {
  constructor(path, options = defaultRecorderOptions) {
    super();

    this._path = path;
    this._options = options;

    this._recorderId = recorderId++;
    this._reset();

    DeviceEventEmitter.addListener('RCTAudioRecorderEvent:' + this._recorderId, (payload: Event) => {
      this._handleEvent(payload.event, payload.data);
    });
  }

  _reset() {
    this._state = MediaStates.IDLE;
    this._duration = -1;
    this._position = -1;
    this._lastSync = -1;
  }

  _updateState(err, state) {
    this._state = err ? MediaStates.ERROR : state;
  }

  _handleEvent(event, data) {
    console.log('event: ' + event + ', data: ' + JSON.stringify(data));
    switch (event) {
      case 'ended':
        this._state = Math.min(this._state, MediaStates.PREPARED);
        break;
      case 'info':
        // TODO
        break;
      case 'error':
        this._reset();
        //this.emit('error', data);
        break;
    }

    this.emit(event, data);
  }

  prepare(callback = _.noop) {
    this._updateState(null, MediaStates.PREPARING);

    // Prepare recorder
    RCTAudioRecorder.prepare(this._recorderId, this._path, this._options, (err) => {
      this._updateState(err, MediaStates.PREPARED);
      callback(err);
    });

    return this;
  }

  record(callback = _.noop) {
    let tasks = [];

    // Make sure recorder is prepared
    if (this._state === MediaStates.IDLE) {
      tasks.push((next) => {
        this.prepare(next);
      });
    }

    // Start recording
    tasks.push((next) => {
        RCTAudioRecorder.record(this._recorderId, next);
    });

    async.series(tasks, (err) => {
      this._updateState(err, MediaStates.RECORDING);
      callback(err);
    });

    return this;
  }

  stop(callback = _.noop) {
    if (this._state >= MediaStates.RECORDING) {
      RCTAudioRecorder.stop(this._recorderId, (err) => {
        this._updateState(err, MediaStates.DESTROYED);
        callback(err);
      });
    } else {
      setTimeout(callback, 0);
    }

    return this;
  }

  toggleRecord(callback = _.noop) {
    if (this._state === MediaStates.RECORDING) {
      this.stop((err) => {
        callback(err, true);
      });
    } else {
      this.record((err) => {
        callback(err, false);
      });
    }

    return this;
  }

  destroy(callback = _.noop) {
    this._reset();
    RCTAudioRecorder.destroy(this._recorderId, callback);
  }

  get state()       { return this._state;                          }
  get canRecord()   { return this._state >= MediaStates.PREPARED;  }
  get canPrepare()  { return this._state == MediaStates.IDLE;      }
  get isRecording() { return this._state == MediaStates.RECORDING; }
  get isPrepared()  { return this._state == MediaStates.PREPARED;  }
}

/**
 * Represents a media player
 * @constructor
 * @param
 *
 */
class Player extends EventEmitter {
  constructor(path, options = defaultPlayerOptions) {
    super();

    this._path = path;
    this._options = options;

    this._playerId = playerId++;
    this._reset();

    DeviceEventEmitter.addListener('RCTAudioPlayerEvent:' + this._playerId, (payload: Event) => {
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

    console.log('got info:');
    console.log(info);

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
    console.log('event: ' + event + ', data: ' + JSON.stringify(data));
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
        this._reset();
        //this.emit('error', data);
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
    RCTAudioPlayer.pause(this._playerId, (err) => {
      this._updateState(err, MediaStates.PAUSED);
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
      this._updateState(err, MediaStates.PREPARED, results);
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
      if (err) {
        // Probably seek operation was cancelled
        console.log(err);
        return;
      }

      this._updateState(null, this._preSeekState, [results]);
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

export { Player, Recorder, MediaStates };
