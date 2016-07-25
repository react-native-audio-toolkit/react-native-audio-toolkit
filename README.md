![banner](/banner.png)

[![npm version](https://badge.fury.io/js/react-native-audio-toolkit.svg)](https://badge.fury.io/js/react-native-audio-toolkit)

This is a cross-platform audio library for React Native. Both audio playback
and recording is supported. Many useful features are included, for example
seeking, looping and playing audio files over network in addition to the basic
play/pause/stop/record functionality.

An example how to use this library is included in the ExampleApp directory. The
demo showcases most of the functionality that is available, rest is documented
in this README file. In the simplest case, an example of media playback is as
follows:

```js
new Player("filename.mp4").play();
```

Example of media recording for 3 seconds followed by playing the file back:

```js
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

### For a quick test, check out the [demo application](/ExampleApp)

or

### [Include the library in your project](/SETUP.md)

Documentation
-------------

### Find the API documentation [here](/API.md)

### Examples on playback from various [media sources](/SOURCES.md)

License
-------

All Android and iOS code here licensed under MIT license, see LICENSE file. Some of the
files are from React Native templates and are licensed accordingly.
