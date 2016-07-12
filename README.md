![banner](/banner.png)

[![npm version](https://badge.fury.io/js/react-native-audio-toolkit.svg)](https://badge.fury.io/js/react-native-audio-toolkit)

This is a cross-platform audio library for React Native. Both audio playback
and recording is supported, but for now only very basic functionality has been
implemented.

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

* `prepare(String path, Function callback, Object ?playbackOptions)`

    Prepare playback of song in `path`.

    Callback is called with `null` as first parameter when song is ready for
    playback with `play()`. If there was an error, the callback is called
    with a String explaining the reason as first parameter.

    playbackOptions fields:
    {
        // Treat path as local filename in app data directory
        local: Boolean (default: false)

        // (Android only) Keep device awake while playing media (NOTE: requires WAKE_LOCK permission)
        partialWakeLock: Boolean (default: false)

        // Initial volume. The scale is 0.0 (silence) - 1.0 (full volume).
        volume: Number (default: 1.0)

        // (iOS only) Enable speed factor adjustment
        enableRate: boolean (default: false)

        // Adjust speed factor of playback
        speed: float (default: 1.0)

        // (Android only) Adjust pitch factor of playback
        pitch: float (default: 1.0)
    }

* `play(String ?path, Function ?callback, Object ?playbackOptions)`

    Start playback.

    If `path` is given, prepare and then immediately play song from `path`.
    If `path` is not given, play prepared/paused song. (throws error if no song
    prepared)

    If callback is given, it is called when playback has started.

    playbackOptions are same as in `prepare()`

* `stop(Boolean destroy)`

    Stop playback.

    If destroy is true, clears all media resources from memory. In this case a
    new song must be loaded with prepare() or play() before the RCTAudioPlayer
    can be used again.

* `pause()`

    Pauses playback. Playback can be resumed by calling `play()` with no
    parameters.

* `getDuration(Function callback)`

    Get duration of prepared/playing media in milliseconds. callback is called
    with result as first parameter. If no duration is available (for example
    live streams), -1 is returned.

* `seekTo(Number pos, Function ?callback)`

    Seek in currently playing media. `pos` is the offset from the start.

    If callback is given, it is called when the seek operation completes.

* `setLooping(boolean loop)`

    Enable/disable repeat

* `setVolume(Number left, Number right)`

    Set volume of left/right audio channels.

    The scale is from 0.0 (silence) to 1.0 (full volume).

### RCTAudioRecorder methods

Method name                  | Description
-----------------------------|------------------------
`record(path)`               | Start recording to file in `path`
`recordLocal(filename)`      | Start recording to `filename` in app data directory
`stop()`                     | Stop recording
`pause()`                    | Pause recording (not implemented)
`resume()`                   | Resume recording (not implemented)

Media events
------------

The project aims to follow
[HTML5 \<audio\> tag](https://developer.mozilla.org/en/docs/Web/Guide/Events/Media_events)
conventions as close as possible, however because React Native events are global,
the events are prefixed with `RCTAudioPlayer` and `RCTAudioRecorder` accordingly:

NOTE: [Media events documentation](https://developer.mozilla.org/en/docs/Web/Guide/Events/Media_events) by
Mozilla Contributors is licensed under [CC-BY-SA 2.5](http://creativecommons.org/licenses/by-sa/2.5/):

### RCTAudioPlayer events

Event name                   | Description
-----------------------------|------------------------
`RCTAudioPlayer:playing`     | Sent when the media begins to play (either for the first time, after having been paused, or after ending and then restarting).
`RCTAudioPlayer:play`        | Sent when playback of the media starts after having been paused; that is, when playback is resumed after a prior *pause* event.
`RCTAudioPlayer:pause`       | Sent when playback is paused.
`RCTAudioPlayer:ended`       | Sent when playback completes.
`RCTAudioPlayer:error`       | Sent when an error occurs. The event handler is passed a string with a reason.
`RCTAudioPlayer:info`        | TODO: https://developer.android.com/reference/android/media/MediaPlayer.OnInfoListener.html

### RCTAudioRecorder events

Event name                   | Description
-----------------------------|------------------------
`RCTAudioPlayer:start`       | Sent when recording starts.
`RCTAudioPlayer:pause`       | Sent when recording is paused. (TODO: implement)
`RCTAudioPlayer:ended`       | Sent when recording completes.
`RCTAudioPlayer:error`       | Sent when an error occurs. The event handler is passed a string with a reason.
`RCTAudioPlayer:info`        | TODO: https://developer.android.com/reference/android/media/MediaRecorder.OnInfoListener.html

License
-------

All Android and iOS code here licensed under MIT license, see LICENSE file. Some of the
files are from React Native templates and are licensed accordingly.
