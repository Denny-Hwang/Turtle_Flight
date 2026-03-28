import { SensitivityConfig } from '../gyro/SensitivityProfile';

export interface FlightState {
  position: { x: number; y: number; z: number };
  rotation: { yaw: number; pitch: number; roll: number };
  speed: number;
  altitude: number;
  heading: number;
  flightTime: number;
  isBoosting: boolean;
  starCount: number;
}

export class FlightEngine {
  private state: FlightState;
  private baseSpeed = 200;
  private boostMultiplier = 1.5;
  private maxSpeed = 500;

  constructor() {
    this.state = this.createInitialState();
  }

  private createInitialState(): FlightState {
    return {
      position: { x: 0, y: 100, z: 0 },
      rotation: { yaw: 0, pitch: 0, roll: 0 },
      speed: 200,
      altitude: 100,
      heading: 0,
      flightTime: 0,
      isBoosting: false,
      starCount: 0,
    };
  }

  update(dt: number, gyroInput: { roll: number; pitch: number }, profile: SensitivityConfig): FlightState {
    // 1. Update heading from roll input
    const turnRate = gyroInput.roll * profile.turnSpeed;
    this.state.heading = (this.state.heading + turnRate * dt + 360) % 360;
    this.state.rotation.yaw = this.state.heading;
    this.state.rotation.roll = gyroInput.roll * 30; // visual bank angle

    // 2. Update pitch
    const pitchRate = gyroInput.pitch * profile.pitchSpeed;
    this.state.rotation.pitch = gyroInput.pitch * 20;

    // 3. Speed calculation
    let targetSpeed = this.baseSpeed;
    if (this.state.isBoosting) {
      targetSpeed = this.baseSpeed * this.boostMultiplier;
    }
    // Stall check
    if (profile.stallEnabled && this.state.speed < profile.stallSpeed) {
      targetSpeed = Math.max(targetSpeed * 0.5, 50);
    }
    this.state.speed += (targetSpeed - this.state.speed) * 2.0 * dt;
    this.state.speed = Math.min(this.state.speed, this.maxSpeed);

    // 4. Position update
    const headingRad = (this.state.heading * Math.PI) / 180;
    const speedMs = this.state.speed / 3.6; // km/h to m/s
    this.state.position.x += Math.sin(headingRad) * speedMs * dt;
    this.state.position.z += Math.cos(headingRad) * speedMs * dt;
    this.state.position.y += pitchRate * dt;

    // 5. Altitude protection
    if (this.state.position.y < profile.minAltitudeProtection) {
      this.state.position.y = Math.max(this.state.position.y, profile.minAltitudeProtection);
    }
    // Max altitude cap
    if (this.state.position.y > 2000) {
      this.state.position.y = 2000;
    }
    this.state.altitude = this.state.position.y;

    // 6. Flight time
    this.state.flightTime += dt;

    return { ...this.state };
  }

  setBoost(active: boolean): void {
    this.state.isBoosting = active;
  }

  collectStar(): void {
    this.state.starCount++;
  }

  getState(): FlightState {
    return { ...this.state };
  }

  reset(): void {
    this.state = this.createInitialState();
  }
}
