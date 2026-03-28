import { VehicleType } from '../../models/VehicleType';

export interface VehicleDefinition {
  id: VehicleType;
  modelScale: number;
  trailEffect: 'flame' | 'sparkle' | 'wind' | 'magic' | 'bubble' | 'feather' | 'cloud';
  trailColor: string;
  soundId: string;
}

export const VEHICLE_DEFINITIONS: Record<VehicleType, VehicleDefinition> = {
  [VehicleType.SHELL_JET]: {
    id: VehicleType.SHELL_JET,
    modelScale: 1.0,
    trailEffect: 'flame',
    trailColor: '#FF6B35',
    soundId: 'jet',
  },
  [VehicleType.BELLY_GLIDER]: {
    id: VehicleType.BELLY_GLIDER,
    modelScale: 1.0,
    trailEffect: 'wind',
    trailColor: '#87CEEB',
    soundId: 'glide',
  },
  [VehicleType.HAMSTER_BALL_COPTER]: {
    id: VehicleType.HAMSTER_BALL_COPTER,
    modelScale: 1.2,
    trailEffect: 'sparkle',
    trailColor: '#F39C12',
    soundId: 'copter',
  },
  [VehicleType.MAGIC_BROOM]: {
    id: VehicleType.MAGIC_BROOM,
    modelScale: 1.0,
    trailEffect: 'magic',
    trailColor: '#9B59B6',
    soundId: 'magic',
  },
  [VehicleType.BALLOON_BODY]: {
    id: VehicleType.BALLOON_BODY,
    modelScale: 1.3,
    trailEffect: 'bubble',
    trailColor: '#1ABC9C',
    soundId: 'balloon',
  },
  [VehicleType.EAR_COPTER]: {
    id: VehicleType.EAR_COPTER,
    modelScale: 1.0,
    trailEffect: 'feather',
    trailColor: '#E74C3C',
    soundId: 'copter',
  },
  [VehicleType.CLOUD_SURF]: {
    id: VehicleType.CLOUD_SURF,
    modelScale: 1.1,
    trailEffect: 'cloud',
    trailColor: '#FFFFFF',
    soundId: 'wind',
  },
};
