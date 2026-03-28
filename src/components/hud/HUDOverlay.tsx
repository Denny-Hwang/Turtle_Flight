import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { FlightState } from '../../core/flight/FlightEngine';
import { formatTime, headingToCompass } from '../../utils/MathHelpers';

interface HUDOverlayProps {
  flightState: FlightState;
  sensitivityLevel: number;
}

export default function HUDOverlay({ flightState, sensitivityLevel }: HUDOverlayProps) {
  const { t } = useTranslation();

  return (
    <View style={styles.container} pointerEvents="none">
      {/* Top left: Speed + Sensitivity */}
      <View style={styles.topLeft}>
        <Text style={styles.label}>{t('flight.speed')}</Text>
        <Text style={styles.value}>{Math.round(flightState.speed)} {t('hud.kmh')}</Text>
        <Text style={styles.small}>Lv.{sensitivityLevel}</Text>
      </View>

      {/* Top center: Compass + Time */}
      <View style={styles.topCenter}>
        <Text style={styles.compass}>{headingToCompass(flightState.heading)}</Text>
        <Text style={styles.heading}>{Math.round(flightState.heading)}°</Text>
        <Text style={styles.time}>{formatTime(flightState.flightTime)}</Text>
      </View>

      {/* Top right: Altitude */}
      <View style={styles.topRight}>
        <Text style={styles.label}>{t('flight.altitude')}</Text>
        <Text style={styles.value}>{Math.round(flightState.altitude)} {t('hud.m')}</Text>
      </View>

      {/* Bottom left: Star counter */}
      <View style={styles.bottomLeft}>
        <Text style={styles.stars}>⭐ x {flightState.starCount}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { ...StyleSheet.absoluteFillObject, padding: 16 },
  topLeft: { position: 'absolute', top: 16, left: 16 },
  topCenter: { position: 'absolute', top: 16, left: 0, right: 0, alignItems: 'center' },
  topRight: { position: 'absolute', top: 16, right: 16, alignItems: 'flex-end' },
  bottomLeft: { position: 'absolute', bottom: 16, left: 16 },
  label: { fontSize: 11, color: '#7FDBFF', fontWeight: '600' },
  value: { fontSize: 22, color: '#FFFFFF', fontWeight: 'bold' },
  small: { fontSize: 10, color: '#7FDBFF', marginTop: 2 },
  compass: { fontSize: 20, color: '#FFFFFF', fontWeight: 'bold' },
  heading: { fontSize: 12, color: '#7FDBFF' },
  time: { fontSize: 16, color: '#FFFFFF', marginTop: 4 },
  stars: { fontSize: 18, color: '#FFD700', fontWeight: 'bold' },
});
