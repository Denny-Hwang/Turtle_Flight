import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';

interface ItemButtonProps {
  onPress: () => void;
}

export default function ItemButton({ onPress }: ItemButtonProps) {
  return (
    <TouchableOpacity style={styles.button} onPress={onPress} activeOpacity={0.7}>
      <Text style={styles.icon}>⭐</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: 'rgba(255, 215, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  icon: { fontSize: 28 },
});
