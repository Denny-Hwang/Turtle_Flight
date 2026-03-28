import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';

interface BoosterButtonProps {
  onPressIn: () => void;
  onPressOut: () => void;
}

export default function BoosterButton({ onPressIn, onPressOut }: BoosterButtonProps) {
  const { t } = useTranslation();

  return (
    <TouchableOpacity
      style={styles.button}
      onPressIn={onPressIn}
      onPressOut={onPressOut}
      activeOpacity={0.7}
    >
      <Text style={styles.icon}>🚀</Text>
      <Text style={styles.label}>{t('flight.boost')}</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    position: 'absolute',
    bottom: 24,
    left: 24,
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: 'rgba(255, 107, 53, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  icon: { fontSize: 28 },
  label: { fontSize: 10, color: '#FFFFFF', fontWeight: '600', marginTop: 2 },
});
