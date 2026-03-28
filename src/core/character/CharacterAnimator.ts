import { CharacterType } from '../../models/CharacterType';
import { VehicleType } from '../../models/VehicleType';

export interface AnimationState {
  characterTilt: { x: number; y: number; z: number };
  vehicleAnimation: string;
  effectIntensity: number;
}

export class CharacterAnimator {
  private currentCharacter: CharacterType = CharacterType.TURBO;
  private currentVehicle: VehicleType = VehicleType.SHELL_JET;

  setCharacter(character: CharacterType, vehicle: VehicleType): void {
    this.currentCharacter = character;
    this.currentVehicle = vehicle;
  }

  update(dt: number, roll: number, pitch: number, speed: number, isBoosting: boolean): AnimationState {
    const bankAngle = roll * 30;
    const pitchAngle = pitch * 15;

    let effectIntensity = speed / 400;
    if (isBoosting) effectIntensity = Math.min(effectIntensity * 1.5, 1.0);

    let vehicleAnimation = 'idle';
    switch (this.currentVehicle) {
      case VehicleType.SHELL_JET:
        vehicleAnimation = isBoosting ? 'jet_boost' : 'jet_cruise';
        break;
      case VehicleType.BELLY_GLIDER:
        vehicleAnimation = Math.abs(roll) > 0.3 ? 'glide_turn' : 'glide_straight';
        break;
      case VehicleType.HAMSTER_BALL_COPTER:
        vehicleAnimation = 'spin';
        break;
      case VehicleType.MAGIC_BROOM:
        vehicleAnimation = isBoosting ? 'broom_fast' : 'broom_cruise';
        break;
      case VehicleType.BALLOON_BODY:
        vehicleAnimation = pitch > 0.2 ? 'inflate' : 'float';
        break;
      case VehicleType.EAR_COPTER:
        vehicleAnimation = 'ear_spin';
        break;
      case VehicleType.CLOUD_SURF:
        vehicleAnimation = Math.abs(roll) > 0.3 ? 'surf_carve' : 'surf_cruise';
        break;
    }

    return {
      characterTilt: { x: pitchAngle, y: 0, z: bankAngle },
      vehicleAnimation,
      effectIntensity,
    };
  }
}
