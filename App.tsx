import React from 'react';
import { StatusBar } from 'react-native';
import InstaRec from './src/components/InstaRec';

const App = () => {
  return (
    <>
      <StatusBar barStyle="dark-content" backgroundColor="#f5f5f5" />
      <InstaRec />
    </>
  );
};

export default App;




