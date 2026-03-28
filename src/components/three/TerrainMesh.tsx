import React, { useMemo } from 'react';
import * as THREE from 'three';
import { PerlinNoise } from '../../utils/PerlinNoise';

interface TerrainMeshProps {
  playerX: number;
  playerZ: number;
}

export default function TerrainMesh({ playerX, playerZ }: TerrainMeshProps) {
  const terrain = useMemo(() => {
    const noise = new PerlinNoise(42);
    const size = 512;
    const segments = 128;
    const geometry = new THREE.PlaneGeometry(size, size, segments, segments);
    geometry.rotateX(-Math.PI / 2);

    const positions = geometry.attributes.position;
    const colors: number[] = [];

    for (let i = 0; i < positions.count; i++) {
      const x = positions.getX(i) * 0.02;
      const z = positions.getZ(i) * 0.02;

      let h = 0;
      h += noise.noise2D(x, z) * 1.0;
      h += noise.noise2D(x * 2, z * 2) * 0.5;
      h += noise.noise2D(x * 4, z * 4) * 0.25;
      h = (h + 1.75) / 3.5;

      positions.setY(i, h * 300);

      // Color by altitude
      let r: number, g: number, b: number;
      if (h < 0.2) { r = 0.12; g = 0.56; b = 1.0; }       // water
      else if (h < 0.3) { r = 0.96; g = 0.82; b = 0.25; }  // sand
      else if (h < 0.6) { r = 0.15; g = 0.68; b = 0.38; }  // grass
      else if (h < 0.8) { r = 0.55; g = 0.27; b = 0.07; }  // mountain
      else { r = 1.0; g = 1.0; b = 1.0; }                   // snow

      colors.push(r, g, b);
    }

    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geometry.computeVertexNormals();

    return geometry;
  }, []);

  return (
    <mesh geometry={terrain} position={[0, 0, 0]}>
      <meshStandardMaterial vertexColors side={THREE.DoubleSide} />
    </mesh>
  );
}
