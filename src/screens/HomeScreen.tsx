import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { FlightMode } from '../models/FlightMode';
import CharacterSelectScreen from './CharacterSelectScreen';
import FlightScreen from './FlightScreen';
import MissionSelectScreen from './MissionSelectScreen';
import SettingsScreen from './SettingsScreen';

type Screen = 'home' | 'characters' | 'flight' | 'missions' | 'settings';

export default function HomeScreen() {
  const { t } = useTranslation();
  const [screen, setScreen] = useState<Screen>('home');
  const [flightMode, setFlightMode] = useState<FlightMode>(FlightMode.FREE_FLIGHT);

  if (screen === 'characters') {
    return <CharacterSelectScreen onBack={() => setScreen('home')} onStart={() => setScreen('flight')} />;
  }
  if (screen === 'flight') {
    return <FlightScreen mode={flightMode} onQuit={() => setScreen('home')} />;
  }
  if (screen === 'missions') {
    return <MissionSelectScreen onBack={() => setScreen('home')} onStart={() => setScreen('flight')} />;
  }
  if (screen === 'settings') {
    return <SettingsScreen onBack={() => setScreen('home')} />;
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{t('app.title')}</Text>
      <Text style={styles.subtitle}>{t('app.subtitle')}</Text>

      <View style={styles.buttons}>
        <TouchableOpacity
          style={styles.mainBtn}
          onPress={() => {
            setFlightMode(FlightMode.FREE_FLIGHT);
            setScreen('characters');
          }}
        >
          <Text style={styles.btnText}>{t('home.freeFlightButton')}</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.mainBtn, styles.missionBtn]}
          onPress={() => {
            setFlightMode(FlightMode.STEP_GOAL);
            setScreen('missions');
          }}
        >
          <Text style={styles.btnText}>{t('home.stepGoalButton')}</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.bottomRow}>
        <TouchableOpacity style={styles.smallBtn} onPress={() => setScreen('characters')}>
          <Text style={styles.smallBtnText}>{t('home.characters')}</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.smallBtn} onPress={() => setScreen('settings')}>
          <Text style={styles.smallBtnText}>{t('home.settings')}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#87CEEB' },
  title: { fontSize: 42, fontWeight: 'bold', color: '#1A1A2E' },
  subtitle: { fontSize: 16, color: '#1A1A2E', marginTop: 8, marginBottom: 40 },
  buttons: { flexDirection: 'row', gap: 16 },
  mainBtn: { backgroundColor: '#2ECC71', paddingHorizontal: 32, paddingVertical: 16, borderRadius: 12 },
  missionBtn: { backgroundColor: '#3498DB' },
  btnText: { fontSize: 18, fontWeight: 'bold', color: '#FFFFFF' },
  bottomRow: { flexDirection: 'row', gap: 16, marginTop: 32 },
  smallBtn: { backgroundColor: 'rgba(255,255,255,0.5)', paddingHorizontal: 20, paddingVertical: 10, borderRadius: 8 },
  smallBtnText: { fontSize: 14, color: '#1A1A2E', fontWeight: '600' },
});
