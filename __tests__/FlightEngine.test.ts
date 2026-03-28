import { FlightEngine } from '../src/core/flight/FlightEngine';
import { SENSITIVITY_PROFILES, SensitivityLevel } from '../src/core/gyro/SensitivityProfile';

describe('FlightEngine', () => {
  let engine: FlightEngine;
  const profile = SENSITIVITY_PROFILES[SensitivityLevel.NORMAL];

  beforeEach(() => {
    engine = new FlightEngine();
  });

  test('initial state has correct defaults', () => {
    const state = engine.getState();
    expect(state.altitude).toBe(100);
    expect(state.speed).toBe(200);
    expect(state.heading).toBe(0);
    expect(state.starCount).toBe(0);
  });

  test('update increments flight time', () => {
    const state = engine.update(1, { roll: 0, pitch: 0 }, profile);
    expect(state.flightTime).toBeCloseTo(1, 1);
  });

  test('roll input changes heading', () => {
    const state = engine.update(1, { roll: 0.5, pitch: 0 }, profile);
    expect(state.heading).toBeGreaterThan(0);
  });

  test('boost increases speed', () => {
    engine.setBoost(true);
    const state = engine.update(2, { roll: 0, pitch: 0 }, profile);
    expect(state.speed).toBeGreaterThan(200);
  });

  test('collectStar increments starCount', () => {
    engine.collectStar();
    engine.collectStar();
    expect(engine.getState().starCount).toBe(2);
  });

  test('altitude protection enforces minimum', () => {
    const state = engine.update(1, { roll: 0, pitch: -1 }, profile);
    expect(state.altitude).toBeGreaterThanOrEqual(profile.minAltitudeProtection);
  });

  test('reset restores initial state', () => {
    engine.update(5, { roll: 1, pitch: 1 }, profile);
    engine.collectStar();
    engine.reset();
    const state = engine.getState();
    expect(state.altitude).toBe(100);
    expect(state.starCount).toBe(0);
  });
});
