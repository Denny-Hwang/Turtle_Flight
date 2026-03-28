import React, { useState } from 'react';
import { View, Text, TouchableOpacity, FlatList, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { CHARACTER_REGISTRY, CharacterConfig } from '../core/character/CharacterRegistry';
import { VehicleType } from '../models/VehicleType';

interface Props {
  onBack: () => void;
  onStart: () => void;
}

export default function CharacterSelectScreen({ onBack, onStart }: Props) {
  const { t } = useTranslation();
  const [selectedIdx, setSelectedIdx] = useState(0);
  const [selectedVehicle, setSelectedVehicle] = useState<VehicleType>(CHARACTER_REGISTRY[0].defaultVehicle);

  const selected = CHARACTER_REGISTRY[selectedIdx];

  const selectCharacter = (idx: number) => {
    setSelectedIdx(idx);
    setSelectedVehicle(CHARACTER_REGISTRY[idx].defaultVehicle);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity style={styles.backBtn} onPress={onBack}>
        <Text style={styles.backText}>{t('common.back')}</Text>
      </TouchableOpacity>

      <Text style={styles.title}>{t('characters.selectTitle')}</Text>

      <FlatList
        data={CHARACTER_REGISTRY}
        horizontal
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        renderItem={({ item, index }) => (
          <TouchableOpacity
            style={[styles.card, selectedIdx === index && { borderColor: item.color, borderWidth: 3 }]}
            onPress={() => selectCharacter(index)}
          >
            <Text style={styles.emoji}>{item.emoji}</Text>
            <Text style={styles.name}>{t(`characters.${item.id}.name`)}</Text>
            <Text style={styles.species}>{t(`characters.${item.id}.species`)}</Text>
          </TouchableOpacity>
        )}
      />

      {/* Vehicle selection */}
      <Text style={styles.sectionTitle}>{t('characters.selectVehicle')}</Text>
      <View style={styles.vehicleRow}>
        {selected.vehicles.map((v) => (
          <TouchableOpacity
            key={v}
            style={[styles.vehicleBtn, selectedVehicle === v && styles.vehicleBtnActive]}
            onPress={() => setSelectedVehicle(v)}
          >
            <Text style={styles.vehicleText}>
              {v === VehicleType.CLOUD_SURF ? t('characters.cloudSurf') : t(`characters.${selected.id}.vehicle`)}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <Text style={styles.desc}>{t(`characters.${selected.id}.desc`)}</Text>

      <TouchableOpacity style={[styles.startBtn, { backgroundColor: selected.color }]} onPress={onStart}>
        <Text style={styles.startText}>{t('home.play')}</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#87CEEB', padding: 20, alignItems: 'center' },
  backBtn: { position: 'absolute', top: 16, left: 16, padding: 8 },
  backText: { fontSize: 16, color: '#1A1A2E', fontWeight: '600' },
  title: { fontSize: 24, fontWeight: 'bold', color: '#1A1A2E', marginTop: 8, marginBottom: 16 },
  list: { paddingHorizontal: 8 },
  card: { backgroundColor: 'rgba(255,255,255,0.6)', borderRadius: 12, padding: 16, marginHorizontal: 6, alignItems: 'center', width: 100 },
  emoji: { fontSize: 36 },
  name: { fontSize: 14, fontWeight: 'bold', color: '#1A1A2E', marginTop: 4 },
  species: { fontSize: 11, color: '#555' },
  sectionTitle: { fontSize: 16, fontWeight: '600', color: '#1A1A2E', marginTop: 16, marginBottom: 8 },
  vehicleRow: { flexDirection: 'row', gap: 12 },
  vehicleBtn: { backgroundColor: 'rgba(255,255,255,0.5)', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20 },
  vehicleBtnActive: { backgroundColor: '#2ECC71' },
  vehicleText: { fontSize: 13, color: '#1A1A2E', fontWeight: '600' },
  desc: { fontSize: 14, color: '#1A1A2E', marginTop: 12, textAlign: 'center' },
  startBtn: { marginTop: 20, paddingHorizontal: 40, paddingVertical: 14, borderRadius: 12 },
  startText: { fontSize: 18, fontWeight: 'bold', color: '#FFFFFF' },
});
