react-native-audio-toolkit
==========================

This is just to show how to record and play audio on Android with React Native.
Coded basically in a day, so as a great thinker of our time Britney Spears once
said, "Don't hold it against me".

Expecting you have managed to run React Native hello world on an actual Android
device (emulators don't help much here) and the development environment is in
place. The index.android.js is almost completely and shamelessly stolen from
https://github.com/jsierles/react-native-audio (not going into the semantics of
stealing when talking about IPR, since it would take more space than the rest of
this README).

Basically everything else is in AudioRecorderModule.java, there is
also AudioPackage.java which makes the module loadable, and the
MainActivity.java is modified to load the native code as well. Also the
AndroidManifest.xml has been modified to include the following lines:

 ```
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

This is the get permissions for recording audio and writing to external storage.

How to get this stuff running?
------------------------------

To make it short:

```
npm install
adb reverse tcp:8081 tcp:8081
react-native run-android
```

Then start clicking the buttons, it should be quite simple.

To open the Java files you really should have Android Studio on your computer,
then open the project in ./android with it. Also make sure you've read
https://facebook.github.io/react-native/docs/native-modules-android.html to know
the basics about native modules.

The audio is always stored to audiorecordtest.mp4 file, AAC is the most
supported format on mobile phones so I'd recommend that (well AMR is also an
option but no, it's not REALLY an option). Check
https://developer.android.com/guide/appendix/media-formats.html for supported
media formats.

Welcome to the wonderful world of React Native development!

Media events
------------

Mostly follows HTML5 <audio> tag conventions:
https://developer.mozilla.org/en/docs/Web/Guide/Events/Media_events

WIP

License
-------

All Java code here licensed under MIT license, see LICENSE file. Some of the files
are from React Native templates and are licensed accordingly.
