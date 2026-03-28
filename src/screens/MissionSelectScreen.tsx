import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { STAGES } from '../core/mission/StageDefinitions';

interface Props {
  onBack: () => void;
  onStart: () => void;
}

export default function MissionSelectScreen({ onBack, onStart }: Props) {
  const { t } = useTranslation();
  const [selectedStage, setSelectedStage] = useState(1);

  return (
    <View style={styles.container}>
      <TouchableOpacity style={styles.backBtn} onPress={onBack}>
        <Text style={styles.backText}>{t('common.back')}</Text>
      </TouchableOpacity>

      <Text style={styles.title}>{t('mission.title')}</Text>

      <View style={styles.stageList}>
        {STAGES.map((stage) => (
          <TouchableOpacity
            key={stage.id}
            style={[styles.stageCard, selectedStage === stage.id && styles.stageCardActive]}
            onPress={() => setSelectedStage(stage.id)}
          >
            <Text style={styles.stageNum}>{t('mission.stage')} {stage.id}</Text>
            <Text style={styles.stageName}>{t(`mission.stage${stage.id}.name`)}</Text>
            <Text style={styles.stageDesc}>{t(`mission.stage${stage.id}.desc`)}</Text>
            <Text style={styles.difficulty}>{'⭐'.repeat(stage.difficulty)}</Text>
          </TouchableOpacity>
        ))}
      </View>

      <TouchableOpacity style={styles.startBtn} onPress={onStart}>
        <Text style={styles.startText}>{t('home.play')}</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#87CEEB', padding: 20, alignItems: 'center' },
  backBtn: { position: 'absolute', top: 16, left: 16, padding: 8 },
  backText: { fontSize: 16, color: '#1A1A2E', fontWeight: '600' },
  title: { fontSize: 24, fontWeight: 'bold', color: '#1A1A2E', marginBottom: 16 },
  stageList: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', gap: 12 },
  stageCard: { backgroundColor: 'rgba(255,255,255,0.6)', borderRadius: 12, padding: 14, width: 150, alignItems: 'center' },
  stageCardActive: { borderColor: '#3498DB', borderWidth: 3 },
  stageNum: { fontSize: 11, color: '#555' },
  stageName: { fontSize: 15, fontWeight: 'bold', color: '#1A1A2E', marginTop: 4 },
  stageDesc: { fontSize: 11, color: '#555', textAlign: 'center', marginTop: 4 },
  difficulty: { fontSize: 12, marginTop: 6 },
  startBtn: { backgroundColor: '#3498DB', paddingHorizontal: 40, paddingVertical: 14, borderRadius: 12, marginTop: 20 },
  startText: { fontSize: 18, fontWeight: 'bold', color: '#FFFFFF' },
});
