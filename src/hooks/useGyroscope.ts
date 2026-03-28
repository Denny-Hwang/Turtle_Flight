import { useState, useEffect, useRef } from 'react';
import { Gyroscope } from 'expo-sensors';
import { SensitivityLevel, SENSITIVITY_PROFILES } from '../core/gyro/SensitivityProfile';

interface GyroInput {
  roll: number;
  pitch: number;
  raw: { x: number; y: number; z: number };
}

export function useGyroscope(sensitivity: SensitivityLevel): GyroInput {
  const [input, setInput] = useState<GyroInput>({ roll: 0, pitch: 0, raw: { x: 0, y: 0, z: 0 } });
  const smoothedRoll = useRef(0);
  const smoothedPitch = useRef(0);
  const profile = SENSITIVITY_PROFILES[sensitivity];

  useEffect(() => {
    Gyroscope.setUpdateInterval(16);

    const subscription = Gyroscope.addListener(({ x, y, z }) => {
      const rollDeg = y * (180 / Math.PI);
      const pitchDeg = x * (180 / Math.PI);

      const rollAfterDZ = Math.abs(rollDeg) < profile.deadZone ? 0 : rollDeg;
      const pitchAfterDZ = Math.abs(pitchDeg) < profile.deadZone ? 0 : pitchDeg;

      const rollClamped = Math.max(-profile.maxTilt, Math.min(profile.maxTilt, rollAfterDZ));
      const pitchClamped = Math.max(-profile.maxTilt, Math.min(profile.maxTilt, pitchAfterDZ));

      const rollNorm = rollClamped / profile.maxTilt;
      const pitchNorm = pitchClamped / profile.maxTilt;

      const rollCurved = Math.sign(rollNorm) * profile.responseCurve(Math.abs(rollNorm));
      const pitchCurved = Math.sign(pitchNorm) * profile.responseCurve(Math.abs(pitchNorm));

      smoothedRoll.current += (rollCurved - smoothedRoll.current) * profile.smoothingAlpha;
      smoothedPitch.current += (pitchCurved - smoothedPitch.current) * profile.smoothingAlpha;

      setInput({
        roll: smoothedRoll.current,
        pitch: smoothedPitch.current,
        raw: { x, y, z },
      });
    });

    return () => subscription.remove();
  }, [sensitivity]);

  return input;
}
