react-native-audio-toolkit demo
===============================

Running the demo app
--------------------

Expecting you have the React Native development environment in place:

#### Android

```sh
cd ExampleApp
npm install         # make sure you do this inside ExampleApp/
npm start

# In a separate terminal, run:
adb reverse tcp:8081 tcp:8081
react-native run-android
```

#### iOS

```sh
cd ExampleApp
npm install         # make sure you do this inside ExampleApp/

# Then:
# 1. Open ExampleApp/ios/ExampleApp.xcodeproj in Xcode
# 2. Click on the run button
```

Then start clicking the buttons, it should be quite simple.
