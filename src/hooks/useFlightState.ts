import { useState, useRef, useCallback } from 'react';
import { FlightEngine, FlightState } from '../core/flight/FlightEngine';
import { SensitivityLevel, SENSITIVITY_PROFILES } from '../core/gyro/SensitivityProfile';

export function useFlightState(sensitivity: SensitivityLevel) {
  const engineRef = useRef(new FlightEngine());
  const [flightState, setFlightState] = useState<FlightState>(engineRef.current.getState());

  const update = useCallback(
    (dt: number, gyroInput: { roll: number; pitch: number }) => {
      const profile = SENSITIVITY_PROFILES[sensitivity];
      const newState = engineRef.current.update(dt, gyroInput, profile);
      setFlightState(newState);
      return newState;
    },
    [sensitivity],
  );

  const setBoost = useCallback((active: boolean) => {
    engineRef.current.setBoost(active);
  }, []);

  const collectStar = useCallback(() => {
    engineRef.current.collectStar();
  }, []);

  const reset = useCallback(() => {
    engineRef.current.reset();
    setFlightState(engineRef.current.getState());
  }, []);

  return { flightState, update, setBoost, collectStar, reset };
}
