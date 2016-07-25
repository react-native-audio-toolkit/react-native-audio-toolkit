Audio sources
=============

Bundle media with application
-----------------------------

If you wish to bundle your media with the application installation files,
follow these steps:

* Android

    Copy your media file file to `android/app/src/main/res/raw/example.mp3`.
    Create any parent directories if necessary. `.mp3` format is recommended for
    best compatibility.

* iOS:

    Drag and drop your media file into the project navigator in Xcode under the
    `AppName/AppName` directory. `.mp3` format is recommended for best
    compatibility.

Your file will now be built into your app's installation file, and you can play
back the file using `new Player.play('example.mp3');`

Stream media over network
-------------------------

Streaming media over network is as simple as providing a network URL to the
`Player` constructor as follows:

```
new Player('https://example.com/test.mp3').play();
```


Note that on iOS, you have to whitelist the domain used if it does not use SSL in the app's 
info.plist file. Otherwise the file won't play.

Playing back local files (Android only)
---------------------------------------

You can play any local files that the app has read permissions to in several
ways. The library tries to find a media file matching the given path in the
following order:

1. Find by filename in app "raw" resources (as in bundle step above, e.g.
   `filename.mp3`)
2. Find by filename in app data directory (e.g. `filename.mp3` becomes
   `/data/user/0/<package_name>/files/filename.mp3`)
3. Find by appending path to the external storage directory (usually `/sdcard`)
4. Find by full path (e.g. `/path/to/file.mp3`)
5. Parse as URI (e.g. `file:///path/to/file.mp3` or
   `https://example.com/file.mp3`)
