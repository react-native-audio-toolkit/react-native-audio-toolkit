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

import {
  RCTAudioPlayer,
  RCTAudioRecorder
} from 'react-native-audio-toolkit';

let audioFilename = 'test.mp4';

class AudioTest extends Component {

  state = {
    recording: false,
    playing: false
  };

  componentWillMount() {
    DeviceEventEmitter.addListener('RCTAudioRecorder_start', (e: Event) => {console.log(e);});
    DeviceEventEmitter.addListener('RCTAudioRecorder_ended', (e: Event) => {
      console.log(e);

      this.setState({recording: false});
    });
    DeviceEventEmitter.addListener('RCTAudioRecorder_error', (e: Event) => {console.log(e);});

    DeviceEventEmitter.addListener('RCTAudioRecorder_info', (e: Event) => {console.log(e);});

    DeviceEventEmitter.addListener('RCTAudioPlayer_playing', (e: Event) => {console.log(e);});
    DeviceEventEmitter.addListener('RCTAudioPlayer_ended', (e: Event) => {
      console.log(e);

      this.setState({playing: false});
    });
    DeviceEventEmitter.addListener('RCTAudioPlayer_pause', (e: Event) => {console.log(e);});
    DeviceEventEmitter.addListener('RCTAudioPlayer_play', (e: Event) => {console.log(e);});
    DeviceEventEmitter.addListener('RCTAudioPlayer_error', (e: Event) => {console.log(e);});

    DeviceEventEmitter.addListener('RCTAudioPlayer_info', (e: Event) => {console.log(e);});
  }

  componentDidMount() {
  }

  _stop() {
    if (this.state.recording) {
      RCTAudioRecorder.stopRecording();
      this.setState({recording: false});
    } else if (this.state.playing) {
      RCTAudioPlayer.stopPlayback();
      this.setState({playing: false});
    }
  }

  _record() {
    if (this.state.playing) {
      this._stop();
    }

    RCTAudioRecorder.startRecordingToFilename(audioFilename);
    this.setState({recording: true});
  }

 _play() {
    if (this.state.recording) {
      this._stop();
    }

    RCTAudioPlayer.playAudioWithFilename(audioFilename);
    this.setState({playing: true});
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
  button: {
    padding: 20
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

AppRegistry.registerComponent('AudioTest', () => AudioTest);
