react-native-audio-toolkit demo
===============================

Running the demo app
--------------------

Expecting you have the React Native development environment in place:

#### Android

![Screenshot](https://cloud.githubusercontent.com/assets/1323963/23828897/d45deda4-0723-11e7-9521-66e556d05c5a.png)


```sh
cd ExampleApp
npm install         # make sure you do this inside ExampleApp/
npm start

# In a separate terminal, run:
adb reverse tcp:8081 tcp:8081
react-native run-android
```

#### iOS

![Screenshot](https://cloud.githubusercontent.com/assets/1323963/23828898/d465810e-0723-11e7-8a65-8b56f2863d96.png)

```sh
cd ExampleApp
npm install         # make sure you do this inside ExampleApp/

# Then:
# 1. Open ExampleApp/ios/ExampleApp.xcodeproj in Xcode
# 2. Click on the run button
```

Then start clicking the buttons, it should be quite simple. By default, the background playback for iOS is enabled.