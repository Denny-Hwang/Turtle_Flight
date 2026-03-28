import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import * as ScreenOrientation from 'expo-screen-orientation';
import './src/i18n';
import HomeScreen from './src/screens/HomeScreen';

export default function App() {
  useEffect(() => {
    ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.LANDSCAPE);
  }, []);

  return (
    <View style={styles.container}>
      <HomeScreen />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#87CEEB' },
});
