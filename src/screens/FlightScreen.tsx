import React, { useCallback } from 'react';
import { View, StyleSheet } from 'react-native';
import { Canvas } from '@react-three/fiber/native';
import { SensitivityLevel } from '../core/gyro/SensitivityProfile';
import { CharacterType } from '../models/CharacterType';
import { VehicleType } from '../models/VehicleType';
import { FlightMode } from '../models/FlightMode';
import { useGyroscope } from '../hooks/useGyroscope';
import { useFlightState } from '../hooks/useFlightState';
import FlightScene from '../components/three/FlightScene';
import HUDOverlay from '../components/hud/HUDOverlay';
import BoosterButton from '../components/controls/BoosterButton';
import ItemButton from '../components/controls/ItemButton';

interface Props {
  mode: FlightMode;
  onQuit: () => void;
}

export default function FlightScreen({ mode, onQuit }: Props) {
  const sensitivity = SensitivityLevel.NORMAL;
  const character = CharacterType.TURBO;
  const vehicle = VehicleType.SHELL_JET;

  const gyroInput = useGyroscope(sensitivity);
  const { flightState, update, setBoost, collectStar } = useFlightState(sensitivity);

  const handleBoostIn = useCallback(() => setBoost(true), [setBoost]);
  const handleBoostOut = useCallback(() => setBoost(false), [setBoost]);
  const handleItem = useCallback(() => {
    // TODO: fire projectile
  }, []);

  return (
    <View style={styles.container}>
      <Canvas style={styles.canvas}>
        <FlightScene
          flightState={flightState}
          character={character}
          vehicle={vehicle}
          gyroInput={gyroInput}
        />
      </Canvas>
      <HUDOverlay flightState={flightState} sensitivityLevel={sensitivity} />
      <BoosterButton onPressIn={handleBoostIn} onPressOut={handleBoostOut} />
      <ItemButton onPress={handleItem} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  canvas: { flex: 1 },
});
