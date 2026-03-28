import { PerlinNoise } from '../../utils/PerlinNoise';

export interface TerrainChunk {
  x: number;
  z: number;
  heightMap: number[][];
  colors: string[][];
}

export class TerrainGenerator {
  private noise: PerlinNoise;
  private chunkSize = 64;
  private scale = 0.02;
  private heightScale = 300;

  constructor(seed?: number) {
    this.noise = new PerlinNoise(seed);
  }

  private colorByAltitude(height: number): string {
    if (height < 0.2) return '#1E90FF';  // water
    if (height < 0.3) return '#F4D03F';  // sand
    if (height < 0.6) return '#27AE60';  // grass
    if (height < 0.8) return '#8B4513';  // mountain
    return '#FFFFFF';                     // snow
  }

  generateChunk(chunkX: number, chunkZ: number): TerrainChunk {
    const heightMap: number[][] = [];
    const colors: string[][] = [];

    for (let i = 0; i < this.chunkSize; i++) {
      heightMap[i] = [];
      colors[i] = [];
      for (let j = 0; j < this.chunkSize; j++) {
        const worldX = (chunkX * this.chunkSize + i) * this.scale;
        const worldZ = (chunkZ * this.chunkSize + j) * this.scale;

        // Multi-octave noise for natural terrain
        let h = 0;
        h += this.noise.noise2D(worldX, worldZ) * 1.0;
        h += this.noise.noise2D(worldX * 2, worldZ * 2) * 0.5;
        h += this.noise.noise2D(worldX * 4, worldZ * 4) * 0.25;
        h = (h + 1.75) / 3.5; // normalize to 0..1

        heightMap[i][j] = h * this.heightScale;
        colors[i][j] = this.colorByAltitude(h);
      }
    }

    return { x: chunkX, z: chunkZ, heightMap, colors };
  }

  getActiveChunks(playerX: number, playerZ: number): TerrainChunk[] {
    const cx = Math.floor(playerX / (this.chunkSize * this.scale * 50));
    const cz = Math.floor(playerZ / (this.chunkSize * this.scale * 50));
    const chunks: TerrainChunk[] = [];

    for (let dx = -1; dx <= 1; dx++) {
      for (let dz = -1; dz <= 1; dz++) {
        chunks.push(this.generateChunk(cx + dx, cz + dz));
      }
    }

    return chunks;
  }
}
