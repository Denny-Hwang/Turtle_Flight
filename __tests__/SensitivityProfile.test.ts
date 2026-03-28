import { SensitivityLevel, SENSITIVITY_PROFILES } from '../src/core/gyro/SensitivityProfile';

describe('SensitivityProfile', () => {
  test('Easy profile has correct dead zone', () => {
    expect(SENSITIVITY_PROFILES[SensitivityLevel.EASY].deadZone).toBe(8);
  });

  test('Normal profile has correct dead zone', () => {
    expect(SENSITIVITY_PROFILES[SensitivityLevel.NORMAL].deadZone).toBe(4);
  });

  test('Expert profile has correct dead zone', () => {
    expect(SENSITIVITY_PROFILES[SensitivityLevel.EXPERT].deadZone).toBe(1.5);
  });

  test('Easy uses cubic response curve', () => {
    const curve = SENSITIVITY_PROFILES[SensitivityLevel.EASY].responseCurve;
    expect(curve(0.5)).toBeCloseTo(0.125, 3); // 0.5^3
  });

  test('Normal uses quadratic response curve', () => {
    const curve = SENSITIVITY_PROFILES[SensitivityLevel.NORMAL].responseCurve;
    expect(curve(0.5)).toBeCloseTo(0.25, 3); // 0.5^2
  });

  test('Expert uses linear response curve', () => {
    const curve = SENSITIVITY_PROFILES[SensitivityLevel.EXPERT].responseCurve;
    expect(curve(0.5)).toBeCloseTo(0.5, 3);
  });

  test('only Expert has stall enabled', () => {
    expect(SENSITIVITY_PROFILES[SensitivityLevel.EASY].stallEnabled).toBe(false);
    expect(SENSITIVITY_PROFILES[SensitivityLevel.NORMAL].stallEnabled).toBe(false);
    expect(SENSITIVITY_PROFILES[SensitivityLevel.EXPERT].stallEnabled).toBe(true);
  });

  test('Expert stall speed is 100 km/h', () => {
    expect(SENSITIVITY_PROFILES[SensitivityLevel.EXPERT].stallSpeed).toBe(100);
  });
});
