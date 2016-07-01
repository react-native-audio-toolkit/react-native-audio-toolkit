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
const AudioPlayer = NativeModules.AudioPlayer;

console.log(AudioRecorder);
console.log(AudioPlayer);

let audioFilename = 'testi.mp4';

class AudioExample extends Component {

  state = {
    currentTime: 0.0,
    recording: false,
    stoppedRecording: false,
    stoppedPlaying: false,
    playing: false,
    finished: false,
    paused: false
  };

  componentWillMount() {
    DeviceEventEmitter.addListener('RCTAudioRecorder:start', console.log);
    DeviceEventEmitter.addListener('RCTAudioRecorder:ended', console.log);
    DeviceEventEmitter.addListener('RCTAudioRecorder:pause', console.log);
    DeviceEventEmitter.addListener('RCTAudioRecorder:error', console.log);

    DeviceEventEmitter.addListener('RCTAudioPlayer:start', console.log);
    DeviceEventEmitter.addListener('RCTAudioPlayer:ended', console.log);
    DeviceEventEmitter.addListener('RCTAudioPlayer:error', console.log);
    DeviceEventEmitter.addListener('RCTAudioPlayer:playing', console.log);
    DeviceEventEmitter.addListener('RCTAudioPlayer:play', console.log);
    DeviceEventEmitter.addListener('RCTAudioPlayer:pause', console.log);

  }

  componentDidMount() {
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
      AudioRecorder.stop();
      this.setState({stoppedRecording: true, recording: false});
    } else if (this.state.playing) {
      AudioPlayer.stop();
      this.setState({playing: false, stoppedPlaying: true});
    }
  }

  _record() {
    AudioRecorder.recordLocal(audioFilename);
    this.setState({recording: true, playing: false});
  }

 _play() {
    if (this.state.recording) {
      this._stop();
      this.setState({recording: false});
    }
    AudioPlayer.playLocal(audioFilename);
    this.setState({playing: true});
  }

  _resume() {
    if (this.state.recording && this.state.paused) {
      AudioRecorder.resume();
      this.setState({paused: false});
    } else if (this.state.playing && this.state.paused) {
      AudioPlayer.resume();
      this.setState({paused: false});
    }
   }

  _pause() {
    if (this.state.recording) {
      AudioRecorder.pause();
      this.setState({paused: true});
    } else if (this.state.playing) {
      AudioPlayer.pause();
      this.setState({paused: true});
    }
  }

  render() {

    return (
      <View style={styles.container}>
        <View style={styles.controls}>
          {this._renderButton("RECORD", () => {this._record()}, this.state.recording )}
          {this._renderButton("STOP", () => {this._stop()} )}
          {this._renderButton("PAUSE", () => {this._pause()} )}
          {this._renderButton("RESUME", () => {this._resume()} )}
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
