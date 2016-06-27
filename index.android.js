/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 * @flow
 */

/*
The MIT License (MIT)

Copyright (c) [2016] [Joshua Sierles]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import React, { Component } from 'react';
import {
  AppRegistry,
  StyleSheet,
  Text,
  View,
  TouchableHighlight,
  NativeModules,
  DeviceEventEmitter
} from 'react-native';

const AudioRecorder = NativeModules.AudioRecorder;

let audioFilename = 'testi.mp4';

class AudioExample extends Component {

  state = {
    currentTime: 0.0,
    recording: false,
    stoppedRecording: false,
    stoppedPlaying: false,
    playing: false,
    finished: false
  };

  componentWillMount() {
    DeviceEventEmitter.addListener('recordingStarted', this._recordingStarted);
    DeviceEventEmitter.addListener('recordingStopped', this._recordingStopped);
    DeviceEventEmitter.addListener('recordingInfo', this._recordingInfo);
    DeviceEventEmitter.addListener('recordingError', this._recordingError);

    DeviceEventEmitter.addListener('playbackStarted', this._playbackStarted);
    DeviceEventEmitter.addListener('playbackStopped', this._playbackStopped);
    DeviceEventEmitter.addListener('playbackPaused', this._playbackPaused);
    DeviceEventEmitter.addListener('playbackResumed', this._playbackResumed);
    DeviceEventEmitter.addListener('playbackInfo', this._playbackInfo);
    DeviceEventEmitter.addListener('playbackError', this._playbackError);
  }

  componentDidMount() {
    AudioRecorder.onProgress = (data) => {
      console.log(data);
      this.setState({currentTime: Math.floor(data.currentTime)});
    };
    AudioRecorder.onFinished = (data) => {
      this.setState({finished: data.finished});
      console.log(`Finished recording: ${data.finished}`);
    };
  }

  _renderButton(title, onPress, active) {
    var style = (active) ? styles.activeButtonText : styles.buttonText;

    return (
      <TouchableHighlight style={styles.button} onPress={onPress}>
        <Text style={style}>
          {title}
        </Text>
      </TouchableHighlight>
    );
  }

  _stop() {
    if (this.state.recording) {
      AudioRecorder.stopRecording();
      this.setState({stoppedRecording: true, recording: false});
    } else if (this.state.playing) {
      AudioRecorder.stopPlaying();
      this.setState({playing: false, stoppedPlaying: true});
    }
  }

  _record() {
    AudioRecorder.startRecordingToFilename(audioFilename);
    this.setState({recording: true, playing: false});
  }

  _recordingStarted(e: Event) {
    console.log("Recording started: ");
    console.log(e);
  }

  _recordingStopped(e: Event) {
    console.log("Recording ended: ");
    console.log(e);
  }

  _recordingInfo(e: Event) {
    console.log("Info about recording: ");
    console.log(e);
  }

  _recordingError(e: Event) {
    console.log("Recording error: ");
    console.log(e);
  }

 _play() {
    if (this.state.recording) {
      this._stop();
      this.setState({recording: false});
    }
    AudioRecorder.playAudioWithFilename(audioFilename);
    this.setState({playing: true});
  }

  _playbackStarted(e: Event) {
    console.log("Playback was started: ");
    console.log(e);
  }

  _playbackStopped(e: Event) {
    console.log("Playback was stopped: ");
    console.log(e);
  }

  _playbackPaused(e: Event) {
    console.log("Playback was paused: ");
    console.log(e);
  }
  _playbackResumed(e: Event) {
    console.log("Playback was resumed: ");
    console.log(e);
  }

  _playbackInfo(e: Event) {
    console.log("Info about playback: ");
    console.log(e);
  }

  _playbackError(e: Event) {
    console.log("Playback error: ");
    console.log(e);
  }

  render() {

    return (
      <View style={styles.container}>
        <View style={styles.controls}>
          {this._renderButton("RECORD", () => {this._record()}, this.state.recording )}
          {this._renderButton("STOP", () => {this._stop()} )}
          {this._renderButton("PLAY", () => {this._play()}, this.state.playing )}
        </View>
      </View>
    );
  }
}

var styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#2b608a",
  },
  controls: {
    justifyContent: 'center',
    alignItems: 'center',
    flex: 1,
  },
  progressText: {
    paddingTop: 50,
    fontSize: 50,
    color: "#fff"
  },
  button: {
    padding: 20
  },
  disabledButtonText: {
    color: '#eee'
  },
  buttonText: {
    fontSize: 20,
    color: "#fff"
  },
  activeButtonText: {
    fontSize: 20,
    color: "#B81F00"
  }

});

AppRegistry.registerComponent('AwesomeProject', () => AudioExample);
