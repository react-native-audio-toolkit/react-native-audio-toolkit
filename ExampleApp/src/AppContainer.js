import React from 'react';
import {
  Text,
  View,
  StyleSheet
} from 'react-native';
import Button from 'react-native-button';

import {
  Player,
  Recorder,
  MediaStates
} from 'react-native-audio-toolkit';

let filename = 'test.mp4';

class AppContainer extends React.Component {
  constructor() {
    super();

    this.state = {
      playPauseButton: 'Preparing...',
      recordButton: 'Preparing...',

      stopButtonDisabled: true,
      playButtonDisabled: true,
      recordButtonDisabled: true
    };

    console.log('mount');

  }

  componentWillMount() {
    this.player = null;
    this.recorder = null;

    this._reloadRecorder();
  }

  componentWillUnmount() {
    console.log('unmount');
    // TODO
  }

  _updateState(err) {
    this.setState({
      playPauseButton: (this.player && this.player.isPlaying) ? 'Pause' : 'Play',
      recordButton: this.recorder && this.recorder.isRecording ? 'Stop' : 'Record',

      stopButtonDisabled: !this.player || (!this.player.isPlaying && !this.player.isPaused),
      playButtonDisabled: !this.player || !this.player.canPlay || this.recorder.isRecording,
      recordButtonDisabled: !this.recorder || (this.player && (this.player.isPlaying || this.player.isPaused))
    });
  }

  _playPause() {
    this.player.playPause((err, playing) => {
      this._updateState();
    });
  }

  _stop() {
    this.player.stop(() => {
      this._updateState();
    });
  }

  _reloadPlayer() {
    console.log('_reloadPlayer()');

    if (this.player) {
      this.player.destroy();
    }

    this.player = new Player(filename, {
      autoDestroy: false
    }).prepare((err) => {
      if (err) {
        console.log('error at _reloadPlayer():');
        console.log(err);
      }

      this._updateState();
    });

    this._updateState();

    this.player.on('ended', () => {
      this._updateState();
    });
  }

  _reloadRecorder() {
    if (this.recorder) {
      this.recorder.destroy();
    }

    this.recorder = new Recorder(filename, {
      bitrate: 256000
    });
    this._updateState();
  }

  _toggleRecord() {
    if (this.player) {
      this.player.destroy();
    }

    this.recorder.toggleRecord((err, stopped) => {
      if (stopped) {
        this._reloadPlayer();
        this._reloadRecorder();
      }

      this._updateState();
    });
  }

  render() {
    return (
      <View>
        <View>
          <Text style={styles.title}>
            Playback
          </Text>
        </View>
        <View style={styles.buttonContainer}>
          <Button disabled={this.state.playButtonDisabled} style={styles.button} onPress={() => this._playPause()}>
            {this.state.playPauseButton}
          </Button>
          <Button disabled={this.state.stopButtonDisabled} style={styles.button} onPress={() => this._stop()}>
            Stop
          </Button>
        </View>
        <View>
          <Text style={styles.title}>
            Recording
          </Text>
        </View>
        <View style={styles.buttonContainer}>
          <Button disabled={this.state.recordButtonDisabled} style={styles.button} onPress={() => this._toggleRecord()}>
            {this.state.recordButton}
          </Button>
        </View>
      </View>
    );
  }
}

var styles = StyleSheet.create({
  button: {
    padding: 20,
    fontSize: 20,
    backgroundColor: 'white',
  },
  buttonContainer: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  container: {
    borderRadius: 4,
    borderWidth: 0.5,
    borderColor: '#d6d7da',
  },
  title: {
    fontSize: 19,
    fontWeight: 'bold',
    textAlign: 'center',
    padding: 20,
  }
});

export default AppContainer;
