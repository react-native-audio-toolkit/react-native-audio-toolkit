Developing the react-native-audio-toolkit library
=================================================

It is recommended to use the [demo application (ExampleApp)](/ExampleApp)
also for library development purposes, and to implement any new features in it
for others to easily try.

Unfortunately it seems that library development for react-native is still a bit
of a hassle. The react-native packager [does not support
symlinks](https://github.com/facebook/watchman/issues/105), which would
otherwise enable us to use `npm link` to symlink the library we're developing
into an example application. There are a number of workarounds for this, but we
found the [wml](https://github.com/wix/wml) tool to work really well.

TODO: find out a better way to do this.

wml setup
---------

1. Start by installing [wml](https://github.com/wix/wml)
2. Install the demo application's dependencies:

    ```
    (cd ExampleApp && npm install)
    ```

3. In the `react-native-audio-toolkit` root directory, run:

    ```
    wml add . ExampleApp/node_modules/react-native-audio-toolkit
    ```

4. Start wml

    ```
    wml start
    ```

This will ensure you can keep working on the library in the original git clone,
and any changes will be immediately visible to the included library in
ExampleApp. Under the hood, wml is watching the source files and copying any
changes to the destination. You only need to do `wml start` when developing in
the future, `wml` will remember any links you've set.

Library structure
=================

The library consists of two parts:

* Native code that implements the device specific media APIs
* JavaScript code that exposes the native methods to React Native developers

The main JavaScript file that exports all library classes is at
[index.js](/index.js). The class implementations are available in [src/](/src)

Native code is available in the [android/](/android) and [ios/](/ios)
directories for respective platforms.

Try to avoid having platform specific code in the JavaScript where possible,
instead abstract these away in the platform specific native code. Other than
that, try to keep as much of the logic as possible in JavaScript.
