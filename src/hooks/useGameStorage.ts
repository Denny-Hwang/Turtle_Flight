import { useState, useEffect, useCallback } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { SensitivityLevel } from '../core/gyro/SensitivityProfile';
import { CharacterType } from '../models/CharacterType';
import { VehicleType } from '../models/VehicleType';
import { StageResult } from '../models/StageResult';

interface GameData {
  selectedCharacter: CharacterType;
  selectedVehicle: VehicleType;
  sensitivity: SensitivityLevel;
  soundEnabled: boolean;
  stageResults: Record<number, StageResult>;
  totalStars: number;
}

const STORAGE_KEY = 'turtle_flight_data';

const DEFAULT_DATA: GameData = {
  selectedCharacter: CharacterType.TURBO,
  selectedVehicle: VehicleType.SHELL_JET,
  sensitivity: SensitivityLevel.NORMAL,
  soundEnabled: true,
  stageResults: {},
  totalStars: 0,
};

export function useGameStorage() {
  const [data, setData] = useState<GameData>(DEFAULT_DATA);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    (async () => {
      const raw = await AsyncStorage.getItem(STORAGE_KEY);
      if (raw) {
        setData({ ...DEFAULT_DATA, ...JSON.parse(raw) });
      }
      setLoaded(true);
    })();
  }, []);

  const save = useCallback(async (updates: Partial<GameData>) => {
    setData((prev) => {
      const next = { ...prev, ...updates };
      AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  const saveStageResult = useCallback(async (result: StageResult) => {
    setData((prev) => {
      const existing = prev.stageResults[result.stageId];
      if (existing && existing.stars >= result.stars) return prev;
      const next = {
        ...prev,
        stageResults: { ...prev.stageResults, [result.stageId]: result },
        totalStars: Object.values({ ...prev.stageResults, [result.stageId]: result }).reduce(
          (sum, r) => sum + r.stars,
          0,
        ),
      };
      AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      return next;
    });
  }, []);

  return { data, loaded, save, saveStageResult };
}
