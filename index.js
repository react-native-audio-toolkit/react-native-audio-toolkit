var { NativeModules } = require('react-native');

var RCTAudioPlayer = NativeModules.AudioPlayer;
var RCTAudioRecorder = NativeModules.AudioRecorder;

export { RCTAudioPlayer, RCTAudioRecorder};

//Audio.basepaths.BUNDLE = RCTAudioPlayer.
//Audio.basepaths.LOCAL_DATA = Audio.

module.exports = Audio;
