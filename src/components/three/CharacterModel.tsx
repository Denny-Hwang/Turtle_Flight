import React, { useRef } from 'react';
import { useFrame } from '@react-three/fiber/native';
import * as THREE from 'three';
import { CharacterType } from '../../models/CharacterType';
import { VehicleType } from '../../models/VehicleType';
import { CHARACTER_REGISTRY } from '../../core/character/CharacterRegistry';

interface CharacterModelProps {
  character: CharacterType;
  vehicle: VehicleType;
  position: [number, number, number];
  rotation: { yaw: number; pitch: number; roll: number };
  isBoosting: boolean;
}

export default function CharacterModel({ character, vehicle, position, rotation, isBoosting }: CharacterModelProps) {
  const groupRef = useRef<THREE.Group>(null);
  const config = CHARACTER_REGISTRY.find((c) => c.id === character);
  const color = config?.color || '#2ECC71';

  useFrame(() => {
    if (!groupRef.current) return;
    groupRef.current.position.set(position[0], position[1], position[2]);
    groupRef.current.rotation.set(
      (rotation.pitch * Math.PI) / 180,
      (rotation.yaw * Math.PI) / 180,
      (rotation.roll * Math.PI) / 180,
    );
  });

  // Low-poly placeholder: sphere body + small sphere head
  return (
    <group ref={groupRef}>
      {/* Body */}
      <mesh>
        <sphereGeometry args={[1.2, 8, 6]} />
        <meshStandardMaterial color={color} />
      </mesh>
      {/* Head */}
      <mesh position={[0, 1.0, 0.5]}>
        <sphereGeometry args={[0.6, 8, 6]} />
        <meshStandardMaterial color={color} />
      </mesh>
      {/* Eyes */}
      <mesh position={[0.25, 1.2, 0.9]}>
        <sphereGeometry args={[0.12, 6, 6]} />
        <meshStandardMaterial color="#000000" />
      </mesh>
      <mesh position={[-0.25, 1.2, 0.9]}>
        <sphereGeometry args={[0.12, 6, 6]} />
        <meshStandardMaterial color="#000000" />
      </mesh>
      {/* Boost trail */}
      {isBoosting && (
        <mesh position={[0, 0, -2]}>
          <coneGeometry args={[0.5, 2, 6]} />
          <meshStandardMaterial color="#FF6B35" emissive="#FF6B35" emissiveIntensity={0.8} />
        </mesh>
      )}
    </group>
  );
}
