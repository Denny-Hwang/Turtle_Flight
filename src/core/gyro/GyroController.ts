import { SensitivityConfig } from './SensitivityProfile';

export interface GyroRawInput {
  x: number;
  y: number;
  z: number;
}

export interface ProcessedGyroInput {
  roll: number;
  pitch: number;
}

export class GyroController {
  private smoothedRoll = 0;
  private smoothedPitch = 0;
  private lastInputTime = 0;
  private noInputDuration = 0;

  process(raw: GyroRawInput, profile: SensitivityConfig, dt: number): ProcessedGyroInput {
    const rollDeg = raw.y * (180 / Math.PI);
    const pitchDeg = raw.x * (180 / Math.PI);

    const rollAfterDZ = Math.abs(rollDeg) < profile.deadZone ? 0 : rollDeg;
    const pitchAfterDZ = Math.abs(pitchDeg) < profile.deadZone ? 0 : pitchDeg;

    const rollClamped = Math.max(-profile.maxTilt, Math.min(profile.maxTilt, rollAfterDZ));
    const pitchClamped = Math.max(-profile.maxTilt, Math.min(profile.maxTilt, pitchAfterDZ));

    const rollNorm = rollClamped / profile.maxTilt;
    const pitchNorm = pitchClamped / profile.maxTilt;

    const rollCurved = Math.sign(rollNorm) * profile.responseCurve(Math.abs(rollNorm));
    const pitchCurved = Math.sign(pitchNorm) * profile.responseCurve(Math.abs(pitchNorm));

    // Track no-input duration for auto-level
    if (Math.abs(rollAfterDZ) < 0.01 && Math.abs(pitchAfterDZ) < 0.01) {
      this.noInputDuration += dt;
    } else {
      this.noInputDuration = 0;
    }

    // Auto-level: lerp towards 0 if no input for autoLevelDelay seconds
    let targetRoll = rollCurved;
    let targetPitch = pitchCurved;
    if (profile.autoLevelDelay > 0 && this.noInputDuration >= profile.autoLevelDelay) {
      targetRoll = 0;
      targetPitch = 0;
    }

    this.smoothedRoll += (targetRoll - this.smoothedRoll) * profile.smoothingAlpha;
    this.smoothedPitch += (targetPitch - this.smoothedPitch) * profile.smoothingAlpha;

    return {
      roll: this.smoothedRoll,
      pitch: this.smoothedPitch,
    };
  }

  reset(): void {
    this.smoothedRoll = 0;
    this.smoothedPitch = 0;
    this.noInputDuration = 0;
  }
}
