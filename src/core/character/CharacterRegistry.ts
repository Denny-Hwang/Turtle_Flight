import { CharacterType } from '../../models/CharacterType';
import { VehicleType } from '../../models/VehicleType';

export interface CharacterConfig {
  id: CharacterType;
  emoji: string;
  defaultVehicle: VehicleType;
  vehicles: VehicleType[];
  color: string;
}

export const CHARACTER_REGISTRY: CharacterConfig[] = [
  {
    id: CharacterType.TURBO,
    emoji: '🐢',
    defaultVehicle: VehicleType.SHELL_JET,
    vehicles: [VehicleType.SHELL_JET, VehicleType.CLOUD_SURF],
    color: '#2ECC71',
  },
  {
    id: CharacterType.PIP,
    emoji: '🐧',
    defaultVehicle: VehicleType.BELLY_GLIDER,
    vehicles: [VehicleType.BELLY_GLIDER, VehicleType.CLOUD_SURF],
    color: '#3498DB',
  },
  {
    id: CharacterType.NUTTY,
    emoji: '🐹',
    defaultVehicle: VehicleType.HAMSTER_BALL_COPTER,
    vehicles: [VehicleType.HAMSTER_BALL_COPTER, VehicleType.CLOUD_SURF],
    color: '#F39C12',
  },
  {
    id: CharacterType.MOCHI,
    emoji: '🐱',
    defaultVehicle: VehicleType.MAGIC_BROOM,
    vehicles: [VehicleType.MAGIC_BROOM, VehicleType.CLOUD_SURF],
    color: '#9B59B6',
  },
  {
    id: CharacterType.BOUNCE,
    emoji: '🐸',
    defaultVehicle: VehicleType.BALLOON_BODY,
    vehicles: [VehicleType.BALLOON_BODY, VehicleType.CLOUD_SURF],
    color: '#1ABC9C',
  },
  {
    id: CharacterType.HOPPY,
    emoji: '🐰',
    defaultVehicle: VehicleType.EAR_COPTER,
    vehicles: [VehicleType.EAR_COPTER, VehicleType.CLOUD_SURF],
    color: '#E74C3C',
  },
];
