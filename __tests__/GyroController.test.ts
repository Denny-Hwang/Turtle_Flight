import { GyroController } from '../src/core/gyro/GyroController';
import { SENSITIVITY_PROFILES, SensitivityLevel } from '../src/core/gyro/SensitivityProfile';

describe('GyroController', () => {
  let controller: GyroController;

  beforeEach(() => {
    controller = new GyroController();
  });

  test('dead zone filters small inputs (Easy)', () => {
    const profile = SENSITIVITY_PROFILES[SensitivityLevel.EASY];
    const result = controller.process({ x: 0.01, y: 0.01, z: 0 }, profile, 0.016);
    expect(Math.abs(result.roll)).toBeLessThan(0.01);
    expect(Math.abs(result.pitch)).toBeLessThan(0.01);
  });

  test('large input produces non-zero output', () => {
    const profile = SENSITIVITY_PROFILES[SensitivityLevel.NORMAL];
    const result = controller.process({ x: 1.0, y: 1.0, z: 0 }, profile, 0.016);
    expect(Math.abs(result.roll)).toBeGreaterThan(0);
    expect(Math.abs(result.pitch)).toBeGreaterThan(0);
  });

  test('expert has smaller dead zone', () => {
    const profileEasy = SENSITIVITY_PROFILES[SensitivityLevel.EASY];
    const profileExpert = SENSITIVITY_PROFILES[SensitivityLevel.EXPERT];
    expect(profileExpert.deadZone).toBeLessThan(profileEasy.deadZone);
  });

  test('reset clears smoothed values', () => {
    const profile = SENSITIVITY_PROFILES[SensitivityLevel.NORMAL];
    controller.process({ x: 2, y: 2, z: 0 }, profile, 0.016);
    controller.reset();
    const result = controller.process({ x: 0, y: 0, z: 0 }, profile, 0.016);
    expect(Math.abs(result.roll)).toBeLessThan(0.01);
    expect(Math.abs(result.pitch)).toBeLessThan(0.01);
  });
});
