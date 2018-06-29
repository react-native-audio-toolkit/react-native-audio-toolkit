//@flow
import React from 'react';
import {Slider, StyleSheet, Switch, Text, TouchableOpacity, View} from 'react-native';
import {Player, Recorder} from 'react-native-audio-toolkit';

const remoteSoundUrl = 'https://archive.org/download/tsp1996-09-17.flac16/tsp1996-09-17d1t09.mp3';
const recordFileName = 'myRecord.mp4';

type State = {
  isLoopingOn: boolean,
  progress: number,
  error?: string,
}

class AppContainer extends React.Component<{}, State> {
  state: State = {
    isLoopingOn: false,
    progress: 0,
  };

  player: ?Player;
  recorder: ?Recorder;
  _progressInterval: IntervalID;

  componentWillMount() {
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
    clearInterval(this._progressInterval);
  }

  /////////// Player

  _reloadPlayer = async () => {
    if (this.player) {
      await this.player.destroy();
    }
    this.player = new Player(recordFileName, {autoDestroy: false});
    this.player.looping = this.state.isLoopingOn;

    try {
      await this.player.prepare();
    } catch (err) {
      console.warn('error at _reloadPlayer():', err);
      return;
    }

    this.player.on('ended', () => this.forceUpdate());
    this.player.on('pause', () => this.forceUpdate());
    this.forceUpdate();
  };

  _playPause = async () => {
    if (this.player) {
      await this.player.playPause();
      this.forceUpdate();
    }
  };

  _stop = async () => {
    if (this.player) {
      await this.player.stop();
      this.forceUpdate();
    }
  };

  _seek = async (percentage: number) => {
    if (this.player) {
      let position = percentage * this.player.duration;
      await this.player.seek(position);
      this.forceUpdate();
    }
  };

  _toggleLooping = (isLoopingOn) => {
    this.setState({isLoopingOn});
    if (this.player) {
      this.player.looping = isLoopingOn;
    }
  };

  /////////// Recorder

  _reloadRecorder = async () => {
    if (this.recorder) {
      await this.recorder.destroy();
    }

    this.recorder = new Recorder(recordFileName, {
      bitrate: 256000,
      channels: 2,
      sampleRate: 44100,
      quality: 'max',
    });

    this.forceUpdate();
  };

  _toggleRecordPause = async () => {
    await this.recorder.toggleRecordPause();
    this.forceUpdate();
  };

  _stopRecord = async () => {
    await this.recorder.stop();
    await this._reloadPlayer();
    await this._reloadRecorder();
    this.forceUpdate();
  };

  _errorCapturer = (func: (any) => any) => {
    return (...args) => {
      try {
        func(...args);
      } catch (err) {
        this.setState({error: err.message});
      }
    };
  };

  render() {
    const playPauseButtonText = this.player && this.player.isPlaying ? 'Pause' : 'Play';
    const playButtonDisabled = !this.player || !this.player.canPlay || this.recorder.isRecording;
    const stopButtonDisabled = !this.player || !this.player.canStop;
    const recordButtonText = this.recorder
    && this.recorder.isRecording
      ? 'Pause'
      : this.recorder.isPaused
        ? 'Resume'
        : 'Record';
    const recordButtonDisabled = !this.recorder || (this.player && !this.player.isStopped);
    const isStopRecordAvailable = this.recorder && (this.recorder.isRecording || this.recorder.isPaused);

    return (
      <View style={styles.container}>
        <Text style={[styles.subTitle, {alignSelf: 'center'}]}>Async API</Text>
        <Text style={styles.partTitle}> Playback </Text>
        <View style={styles.partContainer}>
          <Text style={styles.subTitle}>Controllers</Text>
          <View style={styles.buttonContainer}>
            <Button
              title={playPauseButtonText}
              disabled={playButtonDisabled}
              onPress={this._errorCapturer(this._playPause)}
            />

            <Button
              title="Stop"
              disabled={stopButtonDisabled}
              onPress={this._errorCapturer(this._stop)}
            />

            <View>
              <Switch
                value={this.state.isLoopingOn}
                onValueChange={this._errorCapturer(this._toggleLooping)}
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
            onValueChange={this._errorCapturer(this._seek)}
          />
        </View>

        <Text style={styles.partTitle}> Recording </Text>
        <View style={styles.partContainer}>
          <View style={styles.buttonContainer}>
            <Button
              title={recordButtonText}
              disabled={recordButtonDisabled}
              onPress={this._errorCapturer(this._toggleRecordPause)}
            />

            <Button
              title="Stop"
              disabled={!isStopRecordAvailable}
              onPress={this._errorCapturer(this._stopRecord)}
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
