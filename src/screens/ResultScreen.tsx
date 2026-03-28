import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { StageResult } from '../models/StageResult';
import { formatTime } from '../utils/MathHelpers';

interface Props {
  result: StageResult;
  onRetry: () => void;
  onNext: () => void;
  onMenu: () => void;
}

export default function ResultScreen({ result, onRetry, onNext, onMenu }: Props) {
  const { t } = useTranslation();

  const starsDisplay = '⭐'.repeat(result.stars) + '☆'.repeat(3 - result.stars);

  return (
    <View style={styles.container}>
      <Text style={styles.complete}>{t('mission.complete')}</Text>
      <Text style={styles.stage}>{t('mission.stage')} {result.stageId}</Text>
      <Text style={styles.stars}>{starsDisplay}</Text>
      <Text style={styles.time}>{formatTime(result.timeSeconds)}</Text>
      <Text style={styles.objectives}>
        {result.objectivesCompleted} / {result.objectivesTotal}
      </Text>

      <View style={styles.buttons}>
        <TouchableOpacity style={styles.btn} onPress={onRetry}>
          <Text style={styles.btnText}>{t('mission.retry')}</Text>
        </TouchableOpacity>
        {result.stageId < 5 && (
          <TouchableOpacity style={[styles.btn, styles.nextBtn]} onPress={onNext}>
            <Text style={styles.btnText}>{t('mission.next')}</Text>
          </TouchableOpacity>
        )}
        <TouchableOpacity style={[styles.btn, styles.menuBtn]} onPress={onMenu}>
          <Text style={styles.btnText}>{t('mission.backToMenu')}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#1A1A2E', justifyContent: 'center', alignItems: 'center' },
  complete: { fontSize: 28, fontWeight: 'bold', color: '#2ECC71' },
  stage: { fontSize: 16, color: '#7FDBFF', marginTop: 8 },
  stars: { fontSize: 48, marginTop: 16 },
  time: { fontSize: 20, color: '#FFFFFF', marginTop: 12 },
  objectives: { fontSize: 16, color: '#7FDBFF', marginTop: 8 },
  buttons: { flexDirection: 'row', gap: 16, marginTop: 32 },
  btn: { backgroundColor: '#FF6B35', paddingHorizontal: 24, paddingVertical: 12, borderRadius: 10 },
  nextBtn: { backgroundColor: '#2ECC71' },
  menuBtn: { backgroundColor: '#3498DB' },
  btnText: { fontSize: 16, fontWeight: 'bold', color: '#FFFFFF' },
});
