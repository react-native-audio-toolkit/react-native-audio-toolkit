
var path = require('path');
var blacklist;
try {
  blacklist = require('metro-bundler/src/blacklist');
} catch(e) {
  blacklist = require('metro/src/blacklist');
}
var config = {
  extraNodeModules: {
    'react-native': path.resolve(__dirname, 'node_modules/react-native')
  },
  getBlacklistRE() {
    return blacklist([
      /[/\\]Users[/\\]sangwoo[/\\]workspace[/\\]react-native-audio-toolkit[/\\]node_modules[/\\]react-native[/\\].*/
    ]);
  },
  getProjectRoots() {
    return [
      // Keep your project directory.
      path.resolve(__dirname),
      // Include your forked package as a new root.
      path.resolve('/Users/sangwoo/workspace/react-native-audio-toolkit')
    ];
  }
};

module.exports = config;
