export enum SensitivityLevel {
  EASY = 1,
  NORMAL = 2,
  EXPERT = 3,
}

export interface SensitivityConfig {
  deadZone: number;
  maxTilt: number;
  responseCurve: (x: number) => number;
  smoothingAlpha: number;
  turnSpeed: number;
  pitchSpeed: number;
  autoLevelDelay: number;
  minAltitudeProtection: number;
  stallEnabled: boolean;
  stallSpeed: number;
}

export const SENSITIVITY_PROFILES: Record<SensitivityLevel, SensitivityConfig> = {
  [SensitivityLevel.EASY]: {
    deadZone: 8,
    maxTilt: 25,
    responseCurve: (x: number) => x * x * x,
    smoothingAlpha: 0.08,
    turnSpeed: 45,
    pitchSpeed: 30,
    autoLevelDelay: 2,
    minAltitudeProtection: 50,
    stallEnabled: false,
    stallSpeed: 0,
  },
  [SensitivityLevel.NORMAL]: {
    deadZone: 4,
    maxTilt: 35,
    responseCurve: (x: number) => x * x,
    smoothingAlpha: 0.15,
    turnSpeed: 90,
    pitchSpeed: 60,
    autoLevelDelay: 4,
    minAltitudeProtection: 20,
    stallEnabled: false,
    stallSpeed: 0,
  },
  [SensitivityLevel.EXPERT]: {
    deadZone: 1.5,
    maxTilt: 50,
    responseCurve: (x: number) => x,
    smoothingAlpha: 0.35,
    turnSpeed: 180,
    pitchSpeed: 120,
    autoLevelDelay: 0,
    minAltitudeProtection: 5,
    stallEnabled: true,
    stallSpeed: 100,
  },
};
