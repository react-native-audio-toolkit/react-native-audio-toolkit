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

class AppContainer extends React.Component {
  constructor() {
    super();

    this.state = {
      playPauseButton: 'Preparing...',
      buttonDisabled: true
    };

    console.log('mount');
    if (this.player) {
      this.player.destroy();
    }

    this.player = new Player('https://fruitiex.org/files/rosanna_128kbit.mp3');
    this.player.autoDestroy = false;

    console.log('preparing');
    this.player.prepare(() => {
      console.log('prepared');
      this._updateState();
    });
  }

  componentWillMount() {
  }

  componentWillUnmount() {
    console.log('unmount');
    if (this.player) {
      this.player.destroy();
      this.player = null;
    }
  }

  _updateState(err) {
    this.setState({
      playPauseButton: this.player.state === MediaStates.PLAYING ? 'Pause' : 'Play',
      buttonDisabled: this.player.state < MediaStates.INITIALIZED
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

  render() {
    return (
      <View>
        <View>
          <Text style={styles.title}>
            Playback
          </Text>
        </View>
        <View style={styles.buttonContainer}>
          <Button disabled={this.state.buttonDisabled} style={styles.button} onPress={() => this._playPause()}>
            {this.state.playPauseButton}
          </Button>
          <Button style={styles.button} onPress={() => this._stop()}>
            Stop
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
