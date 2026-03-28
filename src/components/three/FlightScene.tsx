import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber/native';
import * as THREE from 'three';
import { CharacterType } from '../../models/CharacterType';
import { VehicleType } from '../../models/VehicleType';
import { FlightState } from '../../core/flight/FlightEngine';
import CharacterModel from './CharacterModel';
import TerrainMesh from './TerrainMesh';
import SkyBox from './SkyBox';
import FollowCamera from './Camera';

interface FlightSceneProps {
  flightState: FlightState;
  character: CharacterType;
  vehicle: VehicleType;
  gyroInput: { roll: number; pitch: number };
}

export default function FlightScene({ flightState, character, vehicle, gyroInput }: FlightSceneProps) {
  return (
    <>
      <SkyBox />
      <ambientLight intensity={0.6} />
      <directionalLight position={[100, 200, 100]} intensity={0.8} />
      <CharacterModel
        character={character}
        vehicle={vehicle}
        position={[flightState.position.x, flightState.position.y, flightState.position.z]}
        rotation={flightState.rotation}
        isBoosting={flightState.isBoosting}
      />
      <TerrainMesh playerX={flightState.position.x} playerZ={flightState.position.z} />
      <FollowCamera
        targetPosition={[flightState.position.x, flightState.position.y, flightState.position.z]}
        heading={flightState.heading}
        roll={gyroInput.roll}
      />
    </>
  );
}
