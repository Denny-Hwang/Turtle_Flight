import React from 'react';
import * as THREE from 'three';

export default function SkyBox() {
  return (
    <>
      {/* Sky dome */}
      <mesh>
        <sphereGeometry args={[5000, 32, 16]} />
        <meshBasicMaterial color="#87CEEB" side={THREE.BackSide} />
      </mesh>
      {/* Sun */}
      <mesh position={[1000, 800, 500]}>
        <sphereGeometry args={[50, 16, 16]} />
        <meshBasicMaterial color="#FFF8DC" />
      </mesh>
      {/* Simple clouds */}
      {[...Array(20)].map((_, i) => {
        const x = (Math.sin(i * 1.7) * 2000);
        const z = (Math.cos(i * 2.3) * 2000);
        const y = 400 + Math.sin(i * 0.8) * 100;
        const scale = 20 + Math.abs(Math.sin(i * 3.1)) * 30;
        return (
          <mesh key={i} position={[x, y, z]}>
            <sphereGeometry args={[scale, 8, 6]} />
            <meshStandardMaterial color="#FFFFFF" transparent opacity={0.8} />
          </mesh>
        );
      })}
    </>
  );
}
