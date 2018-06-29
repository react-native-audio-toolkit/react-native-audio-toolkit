//@flow
import {DeviceEventEmitter, NativeAppEventEmitter, NativeModules, Platform} from 'react-native';
import async from 'async';
import EventEmitter from 'eventemitter3';
import MediaStates from './MediaStates';
import type {Callback, CallbackWithBoolean, CallbackWithPath, FsPath} from "./TypeDefs";
import type {MediaStateType} from "./MediaStates";

const RCTAudioRecorder = NativeModules.AudioRecorder;

export type RecorderID = number;
let recorderId: RecorderID = 0;

export type RecorderOptions = {
  /** Set bitrate for the recorder, in bits per second. default: 128000 */
  bitrate?: number,

  /**  Set number of channels. default: 2 */
  channels?: number,

  /**  Set how many samples per second. default: 44100 */
  sampleRate?: number,

  /**
   * Override format. Possible values:
   * Cross-platform:  'mp4', 'aac'
   * Android only:    'ogg', 'webm', 'amr'
   * default: based on filename extension
   */
  format?: 'mp4' | 'aac' | 'ogg' | 'webm' | 'amr',

  /** Override encoder. Android only.*/
  encoder?: 'aac' | 'mp4' | 'webm' | 'ogg' | 'amr',

  /** Quality of the recording, iOS only. (default: 'medium') */
  quality?: 'min' | 'low' | 'medium' | 'high' | 'max'
}

const defaultRecorderOptions = {
  autoDestroy: true,
};

/**
 * Represents a media recordemr
 * @constructor
 */
export default class Recorder extends EventEmitter {
  _path: string;
  _fsPath: FsPath;

  _options: RecorderOptions;
  _recorderId: number;
  _state: MediaStateType;

  constructor(path: string, options: RecorderOptions = defaultRecorderOptions) {
    super();
    this._path = path;
    this._options = options;
    this._recorderId = recorderId++;

    this._reset();

    let appEventEmitter = Platform.OS === 'ios' ? NativeAppEventEmitter : DeviceEventEmitter;
    appEventEmitter.addListener('RCTAudioRecorderEvent:' + this._recorderId, (payload: Event) => {
      this._handleEvent(payload.event, payload.data);
    });
  }

  _reset() {
    this._state = MediaStates.IDLE;
  }

  _updateState(err, state) {
    this._state = err ? MediaStates.ERROR : state;
  }

  _handleEvent(event, data) {
    switch (event) {
      case 'ended':
        this._state = Math.min(this._state, MediaStates.PREPARED);
        break;
      case 'info':
        // TODO
        break;
      case 'error':
        this._reset();
        break;
    }

    this.emit(event, data);
  }


  /**
   * Prepare recording to the file provided during initialization.
   * This method is optional to call but it may be beneficial to call to make sure that
   * recording begins immediately after calling record().
   * Otherwise the recording is prepared when calling record() which may result in a small delay.
   *
   * NOTE: Assume that this wipes the destination file immediately.
   *
   *    When ready to record using record(), the callback is called with an empty first parameter.
   *    Second parameter contains a path to the destination file on the filesystem.
   *
   * @param callback
   * @return Promise<FsPath>
   */
  prepare(callback?: CallbackWithPath): Promise<FsPath> {
    const promise = new Promise((resolve, reject) => {
      this._updateState(null, MediaStates.PREPARING);

      RCTAudioRecorder.prepare(this._recorderId, this._path, this._options, (err, fsPath) => {
        this._fsPath = fsPath;
        this._updateState(err, MediaStates.PREPARED);
        if (err) {
          reject(err);
        } else {
          resolve(fsPath);
        }
      });
    });

    return !callback
      ? promise
      : promise.then(path => callback(null, path)).catch(callback);
  }

  /**
   * Start recording to file in path
   *
   * @param callback?
   * @return Promise<FsPath>
   */
  record(callback?: CallbackWithPath): Promise<FsPath> {
    const promise = new Promise((resolve, reject) => {
      let tasks = [];

      // Make sure recorder is prepared
      if (this._state === MediaStates.IDLE) {
        tasks.push(next => this.prepare(next));
      }

      // Start recording
      tasks.push(next => RCTAudioRecorder.record(this._recorderId, next));

      async.series(tasks, (err) => {
        this._updateState(err, MediaStates.RECORDING);
        err ? reject(err) : resolve(this._fsPath);
      });
    });

    return !callback
      ? promise
      : promise.then(path => callback(null, path)).catch(callback);
  }

  /**
   * Stop recording and save the file.
   * Callback is called after recording has stopped or with error object.
   * The recorder is destroyed after calling stop and should no longer be used.
   *
   * @param callback
   * @return Promise<void>
   */
  stop(callback: ?Callback): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      if (this._state >= MediaStates.RECORDING) {
        RCTAudioRecorder.stop(this._recorderId, err => {
          this._updateState(err, MediaStates.DESTROYED);
          err ? reject(err) : resolve();
        });
      } else {
        setTimeout(resolve(), 0);
      }
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   * Pause record
   *
   * @param callback
   * @return {any}
   */
  pause(callback: Callback): Promise<void> {
    const promise = new Promise(((resolve, reject) => {
      if (this._state >= MediaStates.RECORDING) {
        RCTAudioRecorder.pause(this._recorderId, (err) => {
          if (err) {
            reject(err);
          } else {
            this._updateState(err, MediaStates.PAUSED);
            resolve();
          }
        });
      } else {
        setTimeout(resolve, 0);
      }
    }));

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  /**
   * @param callback
   * @return Promise<boolean>
   */
  toggleRecord(callback: CallbackWithBoolean): Promise<boolean> {
    const promise = new Promise((resolve, reject) => {
      if (this._state === MediaStates.RECORDING) {
        this.stop(err => err ? reject(err) : resolve(true));
      } else {
        this.record((err, path) => err ? reject(err) : resolve(false));
      }
    });

    return !callback
      ? promise
      : promise.then((result) => callback(null, result)).catch(callback);
  }

  /**
   * Destroy the recorder.
   * Should only be used if a recorder was constructed, and for some reason is now unwanted.
   *
   * @param callback
   * @return Promise<void>
   */
  destroy(callback: CallbackWithBoolean): Promise<void> {
    const promise = new Promise((resolve, reject) => {
      this._reset();
      RCTAudioRecorder.destroy(this._recorderId, err => err ? reject(err) : resolve());
    });

    return !callback
      ? promise
      : promise.then(callback).catch(callback);
  }

  get state(): MediaStateType {
    return this._state;
  }

  get canRecord(): boolean {
    return this._state >= MediaStates.PREPARED;
  }

  get canPrepare(): boolean {
    return this._state === MediaStates.IDLE;
  }

  get isRecording(): boolean {
    return this._state === MediaStates.RECORDING;
  }

  get isPrepared(): boolean {
    return this._state === MediaStates.PREPARED;
  }

  get fsPath(): FsPath {
    return this._fsPath;
  }
}

