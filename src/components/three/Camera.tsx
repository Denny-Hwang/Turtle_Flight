import React, { useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber/native';
import { CAMERA } from '../../utils/Constants';

interface FollowCameraProps {
  targetPosition: [number, number, number];
  heading: number;
  roll: number;
}

export default function FollowCamera({ targetPosition, heading, roll }: FollowCameraProps) {
  const { camera } = useThree();

  useFrame((_, delta) => {
    const headingRad = (heading * Math.PI) / 180;

    // Camera behind and above the character
    const idealX = targetPosition[0] - Math.sin(headingRad) * CAMERA.FOLLOW_DISTANCE;
    const idealY = targetPosition[1] + CAMERA.FOLLOW_HEIGHT;
    const idealZ = targetPosition[2] - Math.cos(headingRad) * CAMERA.FOLLOW_DISTANCE;

    // Banking offset
    const bankOffset = roll * CAMERA.BANK_FACTOR;

    // Smooth follow with lerp
    const t = 1 - Math.exp(-CAMERA.LERP_SPEED * delta);
    camera.position.x += (idealX + bankOffset - camera.position.x) * t;
    camera.position.y += (idealY - camera.position.y) * t;
    camera.position.z += (idealZ - camera.position.z) * t;

    camera.lookAt(targetPosition[0], targetPosition[1], targetPosition[2]);
  });

  return null;
}
