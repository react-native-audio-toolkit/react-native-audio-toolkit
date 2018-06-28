//@flow
import React from 'react';
import {Slider, StyleSheet, Switch, Text, TouchableOpacity, View} from 'react-native';
import {Player, Recorder} from 'react-native-audio-toolkit';

//let filename = 'https://archive.org/download/tsp1996-09-17.flac16/tsp1996-09-17d1t09.mp3';
let filename = 'test.mp4';

class AppContainer extends React.Component {
  constructor() {
    super();

    this.state = {
      playPauseButton: 'Preparing...',
      recordButton: 'Preparing...',

      stopButtonDisabled: true,
      playButtonDisabled: true,
      recordButtonDisabled: true,

      isLoopingOn: false,
      progress: 0,

      error: null,
    };
  }

  componentWillMount() {
    this.player = null;
    this.recorder = null;

    this._reloadPlayer();
    this._reloadRecorder();

    // Refresh Play progressbar
    const frequencyHz = 5;
    this._progressInterval = setInterval(() => {
      if (this.player && this.player.isPlaying) {
        this.setState({progress: Math.max(0, this.player.currentTime) / this.player.duration});
      }
    }, 1000 / frequencyHz);
  }

  componentWillUnmount() {
    //console.log('unmount');
    // TODO
    clearInterval(this._progressInterval);
  }

  _playPause() {
    this.player.playPause((err, playing) => {
      if (err) {
        this.setState({
          error: err.message,
        });
      }
      this.forceUpdate();
    });
  }

  _stop() {
    this.player.stop(() => {
      this.forceUpdate();
    });
  }

  _seek(percentage) {
    if (!this.player) {
      return;
    }

    let position = percentage * this.player.duration;

    this.player.seek(position, () => {
      this.forceUpdate();
    });
  }

  _reloadPlayer() {
    if (this.player) {
      this.player.destroy();
    }

    this.player = new Player(filename, {
      autoDestroy: false,
    }).prepare((err) => {
      if (err) {
        console.log('error at _reloadPlayer():');
        console.log(err);
      } else {
        this.player.looping = this.state.loopButtonStatus;
      }

      this.forceUpdate();
    });

    this.forceUpdate();

    this.player.on('ended', () => {
      this.forceUpdate();
    });
    this.player.on('pause', () => {
      this.forceUpdate();
    });
  }

  _reloadRecorder() {
    if (this.recorder) {
      this.recorder.destroy();
    }

    this.recorder = new Recorder(filename, {
      bitrate: 256000,
      channels: 2,
      sampleRate: 44100,
      quality: 'max',
      //format: 'ac3', // autodetected
      //encoder: 'aac', // autodetected
    });

    this.forceUpdate();
  }

  _toggleRecord() {
    if (this.player) {
      this.player.destroy();
    }

    this.recorder.toggleRecord((err, stopped) => {
      if (err) {
        this.setState({
          error: err.message,
        });
      }
      if (stopped) {
        this._reloadPlayer();
        this._reloadRecorder();
      }

      this.forceUpdate();
    });
  }

  _toggleLooping(value) {
    console.log(value)
    this.setState({
      isLoopingOn: value,
    });
    if (this.player) {
      this.player.looping = value;
    }
  }

  render() {
    console.log(this.player.state);
    const playPauseButtonText = this.player && this.player.isPlaying ? 'Stop' : 'Play';
    const playButtonDisabled = !this.player || !this.player.canPlay || this.recorder.isRecording;
    const stopButtonDisabled = !this.player || !this.player.canStop;
    const recordButtonText = this.recorder && this.recorder.isRecording ? 'Pause' : 'Record';
    const recordButtonDisabled = !this.recorder || (this.player && !this.player.isStopped);

    return (
      <View style={styles.container}>
        <Text style={styles.partTitle}> Playback </Text>
        <View style={styles.partContainer}>
          <Text style={styles.subTitle}>Controllers</Text>
          <View style={styles.buttonContainer}>
            <Button
              title={playPauseButtonText}
              disabled={playButtonDisabled}
              onPress={() => this._playPause()}
            />

            <Button
              title="Stop"
              disabled={stopButtonDisabled}
              onPress={() => this._stop()}
            />

            <View>
              <Switch
                value={this.state.isLoopingOn}
                onValueChange={(value) => this._toggleLooping(value)}
              />
              <Text>Toggle{'\n'} Looping</Text>
            </View>
          </View>

          <Text style={styles.subTitle}>Seek bar</Text>
          <Slider
            style={{marginTop: 20}}
            step={0.0001}
            disabled={playButtonDisabled}
            value={this.state.progress}
            onValueChange={() => this._seek()}
          />
        </View>

        <Text style={styles.partTitle}> Recording </Text>
        <View style={styles.partContainer}>
          <View style={styles.buttonContainer}>
            <Button
              title={recordButtonText}
              disabled={recordButtonDisabled}
              onPress={() => this._toggleRecord()}
            />

          </View>
        </View>

        <Text style={styles.errorMessage}>{this.state.error}</Text>
      </View>
    );
  }
}

type ButtonStyle = {
  title: string,
  style?: any,
  disabled?: boolean,
  onPress: () => any,
};

const Button = (props: ButtonStyle) =>
  <TouchableOpacity
    style={[{backgroundColor: 'lightgrey', padding: 20}, props.style]}
    onPress={props.disabled ? undefined : props.onPress}
  >
    <Text style={{color: props.disabled ? "grey" : "blue"}}>
      {props.title}
    </Text>
  </TouchableOpacity>;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'stretch',
    padding: 20,
  },
  partTitle: {
    marginTop: 10,
    alignSelf: 'flex-start',
    fontSize: 19,
    fontWeight: 'bold',
    textAlign: 'center',
    padding: 10,
  },
  partContainer: {
    backgroundColor: 'white',
    borderWidth: 1,
    borderColor: 'darkgray',
    paddingHorizontal: 10,
    paddingVertical: 20,
  },
  subTitle: {
    marginTop: 10,
    fontSize: 16,
  },
  buttonContainer: {
    padding: 10,
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
  },
  slider: {
    height: 10,
    margin: 10,
  },
  errorMessage: {
    fontSize: 15,
    textAlign: 'center',
    padding: 10,
    color: 'red',
  },
});

export default AppContainer;
