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
      buttonDisabled: true
    };

    console.log('mount');

    this.player = null;

    this.recorder = new Recorder(filename, {
      autoDestroy: false
    }).prepare(() => {
      this._updateState();
    });
  }

  componentWillMount() {
    // TODO should we initialize player/recorder here instead?
  }

  componentWillUnmount() {
    console.log('unmount');
    // TODO
  }

  _updateState(err) {
    console.log('player.state: ' + (this.player ? this.player.state : -1) + ' ' + (this.recorder ? this.recorder.state : -1));

    this.setState({
      stopButtonDisabled: !this.player || (this.player.state !== MediaStates.PLAYING && this.player.state !== MediaStates.PAUSED),
      playPauseButton: (this.player && this.player.state === MediaStates.PLAYING) ? 'Pause' : 'Play',
      playButtonDisabled: !this.player || (this.player.state < MediaStates.PREPARED || this.recorder.state === MediaStates.RECORDING),
      recordButton: this.recorder.state === MediaStates.RECORDING ? 'Stop' : 'Record',
      recordButtonDisabled: this.recorder.state < MediaStates.PREPARED,
    });
  }

  _playPause() {
    this.player.playPause(() => {
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

    this.player.on('ended', () => {
      this._updateState();
    });
  }

  _toggleRecord() {
    this.recorder.toggleRecord(() => {
      console.log('state1 was ' + this.recorder.state);
      if (this.recorder.state !== MediaStates.RECORDING) {
        console.log('stopped');
        console.log('state2 was ' + this.recorder.state);
        setTimeout(() => {
          this._reloadPlayer();
        }, 1000);
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
