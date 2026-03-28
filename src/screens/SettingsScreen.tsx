import React from 'react';
import { View, Text, TouchableOpacity, FlatList, StyleSheet } from 'react-native';
import { useTranslation } from 'react-i18next';
import { SUPPORTED_LANGUAGES } from '../i18n';

interface Props {
  onBack: () => void;
}

export default function SettingsScreen({ onBack }: Props) {
  const { t, i18n } = useTranslation();

  const changeLanguage = (code: string) => {
    i18n.changeLanguage(code);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity style={styles.backBtn} onPress={onBack}>
        <Text style={styles.backText}>{t('common.back')}</Text>
      </TouchableOpacity>

      <Text style={styles.title}>{t('settings.title')}</Text>

      {/* Language selection */}
      <Text style={styles.sectionTitle}>{t('settings.language')}</Text>
      <FlatList
        data={SUPPORTED_LANGUAGES}
        horizontal
        keyExtractor={(item) => item.code}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={[styles.langButton, i18n.language === item.code && styles.langButtonActive]}
            onPress={() => changeLanguage(item.code)}
          >
            <Text style={[styles.langText, i18n.language === item.code && styles.langTextActive]}>
              {item.nativeLabel}
            </Text>
          </TouchableOpacity>
        )}
      />

      {/* Sensitivity selection */}
      <Text style={styles.sectionTitle}>{t('settings.sensitivity')}</Text>
      <View style={styles.sensitivityRow}>
        {(['Easy', 'Normal', 'Expert'] as const).map((level) => (
          <View key={level} style={styles.sensitivityCard}>
            <Text style={styles.sensitivityLabel}>{t(`settings.sensitivity${level}`)}</Text>
            <Text style={styles.sensitivityDesc}>{t(`settings.sensitivityDesc${level}`)}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 24, backgroundColor: '#87CEEB' },
  backBtn: { position: 'absolute', top: 16, left: 16, padding: 8, zIndex: 1 },
  backText: { fontSize: 16, color: '#1A1A2E', fontWeight: '600' },
  title: { fontSize: 28, fontWeight: 'bold', color: '#1A1A2E', marginBottom: 24, textAlign: 'center' },
  sectionTitle: { fontSize: 18, fontWeight: '600', color: '#1A1A2E', marginTop: 20, marginBottom: 12 },
  langButton: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.5)', marginRight: 8 },
  langButtonActive: { backgroundColor: '#2ECC71' },
  langText: { fontSize: 15, color: '#1A1A2E' },
  langTextActive: { color: '#FFFFFF', fontWeight: '600' },
  sensitivityRow: { flexDirection: 'row', gap: 12 },
  sensitivityCard: { flex: 1, backgroundColor: 'rgba(255,255,255,0.5)', borderRadius: 12, padding: 12, alignItems: 'center' },
  sensitivityLabel: { fontSize: 16, fontWeight: 'bold', color: '#1A1A2E' },
  sensitivityDesc: { fontSize: 11, color: '#555', textAlign: 'center', marginTop: 4 },
});
