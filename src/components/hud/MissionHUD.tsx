import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { MissionState } from '../../core/mission/MissionEngine';

interface MissionHUDProps {
  missionState: MissionState;
}

export default function MissionHUD({ missionState }: MissionHUDProps) {
  const { t } = useTranslation();

  return (
    <View style={styles.container} pointerEvents="none">
      <Text style={styles.stage}>
        {t('mission.stage')} {missionState.stageId}
      </Text>
      <Text style={styles.objective}>
        {missionState.objectivesCompleted} / {missionState.objectivesTotal}
      </Text>
      {missionState.isComplete && (
        <Text style={styles.complete}>{t('mission.complete')}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { position: 'absolute', top: 60, left: 0, right: 0, alignItems: 'center' },
  stage: { fontSize: 14, color: '#7FDBFF', fontWeight: '600' },
  objective: { fontSize: 20, color: '#FFD700', fontWeight: 'bold', marginTop: 4 },
  complete: { fontSize: 24, color: '#2ECC71', fontWeight: 'bold', marginTop: 8 },
});
