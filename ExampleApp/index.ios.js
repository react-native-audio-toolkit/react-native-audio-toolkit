import React from 'react';
import {AppRegistry} from 'react-native';
import AppContainer from './src/AppContainer';

class ExampleApp extends React.Component {
  render() {
    return (
      <AppContainer />
    );
  }
}

AppRegistry.registerComponent('ExampleApp', () => ExampleApp);
