![banner](/banner.png)

[![npm version](https://badge.fury.io/js/react-native-audio-toolkit.svg)](https://badge.fury.io/js/react-native-audio-toolkit)

This is a cross-platform audio library for React Native. Both audio playback
and recording is supported. Many useful features are included, for example seeking, looping and playing audio files over network in addition
to the basic play/pause/stop/record functionality.

An example how to use this library is included in the ExampleApp directory. The demo showcases most of the functionality that is available,
rest is documented in this README file. In the simplest case, an example of media playback is as follows:

```
new Player("filename.mp4").play();
```

Example of media recording for 3 seconds followed by playing the file back:

```
let rec = new Recorder("filename.mp4").record();

setTimeout(() => {
  rec.stop((err) => {
    if (err) { return console.log(err); }
    new Player("filename.mp4").play();
  });
}, 3000);
```

How to get this stuff running?
------------------------------

### Example app

Expecting you have the React Native development environment in place:

#### [Android](ExampleApp/index.android.js)

```
cd ExampleApp
npm install         # make sure you do this inside ExampleApp/
npm start

# In a separate terminal, run:
adb reverse tcp:8081 tcp:8081
react-native run-android
```

#### [iOS](ExampleApp/index.ios.js)

```
cd ExampleApp
npm install         # make sure you do this inside ExampleApp/

Then:
1. Open ExampleApp/ios/ExampleApp.xcodeproj in Xcode
2. Click on the run button
```

Then start clicking the buttons, it should be quite simple.

### Including the library in your project

Expecting you have the React Native development environment in place, are
starting with a React Native hello world project and have managed to run it on
an actual Android/iOS device:

* Install library via npm

    ```
    npm install --save react-native-audio-toolkit
    ```

### Android

1. Append dependency to end of `android/settings.gradle` file

    ```
    ...

    include ':react-native-audio-toolkit'
    project(':react-native-audio-toolkit').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-audio-toolkit/android/lib')
    ```

2. Add dependency to `android/app/build.gradle`

    ```
    ...

    dependencies {
        ...
        compile project(':react-native-audio-toolkit')
    }
    ```

3. Register the module in `android/app/src/main/java/com/<project>/MainApplication.java`

    ```
    package com.<project>;

    import com.facebook.react.ReactActivity;
    import com.facebook.react.ReactPackage;
    import com.facebook.react.shell.MainReactPackage;

    import com.futurice.rctaudiotoolkit.AudioPackage; // <-------- here

    ...

    protected List<ReactPackage> getPackages() {
        return Arrays.<ReactPackage>asList(
            ...
            new MainReactPackage(),
            new AudioPackage() // <------------------------------- here
        );
    }
    ```

4. (optional) If you wish to record audio, add the following permissions to
   `android/app/src/main/AndroidManifest.xml`

    ```
    <manifest ...>

        <uses-permission android:name="android.permission.RECORD_AUDIO" />
        <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
        ...

    </manifest>
    ```

    This is to get permissions for recording audio and writing to external storage.

    TODO: Android 6.0 permissions model once supported by React Native:
    https://facebook.github.io/react-native/docs/known-issues.html#android-m-permissions

### iOS

1. Right click `Libraries`, click `Add Files to "ExampleApp"`
2. Select `node_modules/react-native-audio-toolkit/ios/ReactNativeAudioToolkit/ReactNativeAudioToolkit.xcodeproj`
3. Select your app from the Project Navigator, click on the `Build Phases` tab.
   Expand `Link Binary With Libraries`. Click the plus and add
   `libReactNativeAudioToolkit.a` from under Workspace.

Media methods
-------------

### RCTAudioPlayer methods

* `new Player(String path, Object ?playbackOptions)`

    Initialize the player for playback of song in `path`. Path can be either filename, network URL or a file URL to resource. The library tries to parse the provided path to the best of it's abilities.

    ```
    playbackOptions:
    {
      // Boolean to indicate whether the player should self-destruct after playback is finished.
      // If this is not set, you are responsible for destroying the object by calling player.destroy().
      autoDestroy : boolean (default: True)
    }
    ```

* `prepare(Function callback)`

    Prepare playback of the file provided during initialization. This method is optional to call but
    might be useful to preload the file so that the file starts playing immediately when calling
    play(). Otherwise the file is prepared when calling play() which may result in a small delay.

    Callback is called with `null` as first parameter when file is ready for
    playback with `play()`. If there was an error, the callback is called
    with an error object as first parameter. See Callbacks for more information.


* `play(Function ?callback)`

    Start playback.

    If callback is given, it is called when playback has started.


* `pause(Function ?callback)`

    Pauses playback. Playback can be resumed by calling `play()` with no
    parameters.

    Callback is called after the operation has finished.


* `playPause(Function ?callback)`

    Helper method for toggling pause.

    Callback is called after the operation has finished. Callback receives `Object error` as first argument, `Boolean playing` as second argument indicating if the player ended up playing (true) or paused (false).


* `stop(Function ?callback)`

    Stop playback.

    If `autoDestroy` option was set during initialization, clears all media resources from memory. In this case the player should no longer be used.


* `destroy(Function ?callback)`

    Stops playback and destroys the player. The player should no longer be used.

    Callback is called after the operation has finished.


* `seek(Number position, Function ?callback)`

    Seek in currently playing media. `position` is the offset from the start.

    If callback is given, it is called when the seek operation completes. If
    another seek operation is performed before the previous has finished,
    the previous operation gets an error in its callback with the `err` field
    set to `oldcallback`. The previous operation should likely do nothing in
    this case.


### RCTAudioPlayer properties

The following properties can be read and manipulated directly on the Player instance, for example:

```
var p = new Player(...);
p.looping = true;
p.volume = 0.5;

p.prepare((err) => {
  ...
  console.log(p.duration);
});
```

* `looping` - Boolean, default `false`

    Get/set looping status of the current file. If true, file will loop when playback reaches end of file.

* `volume` - Number, default `1.0`

    Get/set playback volume.
    The scale is from 0.0 (silence) to 1.0 (full volume).

* `duration` - Number (**read only**)

    Get duration of prepared/playing media in milliseconds. If no duration is available (for example live streams), -1 is returned.

* `wakeLock` - Boolean, default: `false` (Android only)

    Get/set wakeLock on player, keeping it alive in the background.

    TODO: support attaching to media notification

* `currentTime` - Number

    Get/set current playback position in milliseconds. It's recommended to do seeking via `Player.seek()`,
    as it is not possible to pass a callback when setting the `currentTime` property.

* `state` - Number (**read only**)

    Get the playback state. Can be one of:
    ```
    var MediaStates = {
      DESTROYED: -2,
      ERROR: -1,
      IDLE: 0,
      PREPARING: 1,
      PREPARED: 2,
      SEEKING: 3,
      PLAYING: 4,   // only for Player
      RECORDING: 4, // only for Recorder
      PAUSED: 5
    };
    ```

    NOTE: This object is available as `require('react-native-audio-toolkit').MediaStates`

* Helpers for states - Boolean (**read only**)

  ```
  Player.canPlay      true if player can begin playback
  Player.canStop      true if player can stop playback
  Player.canPrepare   true if player can prepare for playback
  Player.isPlaying    true if player is playing
  Player.isStopped    true if player is stopped
  Player.isPaused     true if player is paused
  Player.isPrepared   true if player is prepared
  ```


### RCTAudioRecorder methods

* `new Recorder(String path, Object ?playbackOptions)`

    Initialize the recorder for recording to file in `path`. Path can either be a filename or a
    file URL (Android only). The library tries to parse the provided path to the best of it's abilities.

    Playback options can include the following settings:

    ```
    playbackOptions:
    {
      // Set bitrate for the recorder, in bits per second
      bitrate : Number (default: 128000)

      // Set number of channels
      channels : Number (default: 2)

      // Set how many samples per second
      sampleRate : Number (default: 44100)

      // Override format. Possible values:
      // Cross-platform:  'mp4', 'aac'
      // Android only:    'ogg', 'webm', 'amr'
      format : String (default: based on filename extension)

      // Override encoder. Android only.
      // Possible values:
      // 'aac', 'mp4', 'webm', 'ogg', 'amr'
      encoder : String (default: based on filename extension)

      // Quality of the recording, iOS only.
      // Possible values: 'min', 'low', 'medium', 'high', 'max'
      quality : String (default: 'medium')
    }
    ```

* `prepare(Function callback)`

    Prepare recording to the file provided during initialization. This method is optional to call but it may be beneficial to call to make sure that recording begins immediately after calling record(). Otherwise the recording is prepared when calling record() which may result in a small delay.

    Callback is called with `null` as first parameter when file is ready for
    recording with `record()`. If there was an error, the callback is called
    with an error object as first parameter. See Callbacks for more information.


* `record(Function ?callback)`

    Start recording to file in `path`. Callback is called after recording has started or with
    error object if an error occurred.


* `stop(Function ?callback)`

    Stop recording and save the file. Callback is called after recording has stopped or with error object. The
    recorder is destroyed after calling stop and should no longer be used.

Events
------

Certain events are dispatched from the Player/Recorder object to provide additional
information concerning playback or recording. The following events are supported:

* `error` - An error has occurred and the object is rendered unusable

* `ended` - Recording or playback of current file has finished. You can restart playback with a Player object by calling play() again.

* `looped` - Playback of a file has looped.


Listen to these events with  `player.on('eventname', callback(data))`.
Data may contain additional information about the event, for example a more
detailed description of the error that occurred. You might also want to update your user interface or start playing a new file after file playback or recording has concluded.

If an error occurs, the object should be destroyed. If the object is not destroyed,
future behavior is undefined.

Callbacks
---------

If everything goes smoothly, the provided callback when calling Player/Recorder methods are called with an empty parameter. In case of an error however, the callback is called with an object that contains data about the error in the following format:

```
{
  err : $errorString,
  message : 'Additional information',
  stackTrace : $stackTrace
}
```

The following $errorStrings might occur:
 ```
'invalidpath' - Malformed path was provided
'preparefail' - Failed to initialize player/recorder
'startfail' - Failed to start the player/recorder
'notfound' - Player/recorder with provided id was not found
'stopfail' - Failed to stop recording/playing
```

### Player-specific error callbacks:
```
'seekfail' - new seek operation before the old one completed.
```


License
-------

All Android and iOS code here licensed under MIT license, see LICENSE file. Some of the
files are from React Native templates and are licensed accordingly.
