![banner](/banner.png)

[![npm version](https://badge.fury.io/js/react-native-audio-toolkit.svg)](https://badge.fury.io/js/react-native-audio-toolkit)

This is a cross-platform (Android and iOS) audio library for React Native.
Both audio playback and recording is supported. Many useful features are
included, for example seeking, looping and playing audio files over network in
addition to the basic play/pause/stop/record functionality.

An example how to use this library is included in the ExampleApp directory. The
demo showcases most of the functionality that is available, rest is documented
under [docs](/docs). In the simplest case, an example of media playback is as
follows:

```js
new Player("filename.mp4").play();
```

How to get this stuff running?
------------------------------

* For a quick test, check out the [demo application](/ExampleApp)
* [Include the library](/docs/SETUP.md) in your project

Documentation
-------------

* Find the API documentation [here](/docs/API.md)
* Examples on playback from various [media sources](/docs/SOURCES.md)

License
-------

All Android and iOS code licensed under MIT license, see LICENSE file. Some of
the files are from React Native templates and are licensed accordingly.
