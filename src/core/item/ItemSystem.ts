export interface StarItem {
  id: string;
  position: { x: number; y: number; z: number };
  collected: boolean;
  rotationY: number;
}

export interface Projectile {
  id: string;
  position: { x: number; y: number; z: number };
  direction: { x: number; y: number; z: number };
  speed: number;
  lifetime: number;
}

export class ItemSystem {
  private stars: StarItem[] = [];
  private projectiles: Projectile[] = [];
  private nextId = 0;
  private collectRadius = 15;

  spawnStarsAroundPlayer(px: number, py: number, pz: number, count: number): void {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const dist = 100 + Math.random() * 400;
      this.stars.push({
        id: `star_${this.nextId++}`,
        position: {
          x: px + Math.cos(angle) * dist,
          y: py - 30 + Math.random() * 60,
          z: pz + Math.sin(angle) * dist,
        },
        collected: false,
        rotationY: 0,
      });
    }
  }

  fireProjectile(px: number, py: number, pz: number, heading: number): void {
    const rad = (heading * Math.PI) / 180;
    this.projectiles.push({
      id: `proj_${this.nextId++}`,
      position: { x: px, y: py, z: pz },
      direction: { x: Math.sin(rad), y: 0, z: Math.cos(rad) },
      speed: 200,
      lifetime: 3,
    });
  }

  update(dt: number, playerPos: { x: number; y: number; z: number }): number {
    let collected = 0;

    // Update stars
    for (const star of this.stars) {
      if (star.collected) continue;
      star.rotationY += dt * 2;
      const dx = star.position.x - playerPos.x;
      const dy = star.position.y - playerPos.y;
      const dz = star.position.z - playerPos.z;
      const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist < this.collectRadius) {
        star.collected = true;
        collected++;
      }
    }

    // Update projectiles
    for (const proj of this.projectiles) {
      proj.position.x += proj.direction.x * proj.speed * dt;
      proj.position.y += proj.direction.y * proj.speed * dt;
      proj.position.z += proj.direction.z * proj.speed * dt;
      proj.lifetime -= dt;
    }

    // Cleanup
    this.projectiles = this.projectiles.filter((p) => p.lifetime > 0);

    return collected;
  }

  getStars(): StarItem[] {
    return this.stars.filter((s) => !s.collected);
  }

  getProjectiles(): Projectile[] {
    return this.projectiles;
  }

  reset(): void {
    this.stars = [];
    this.projectiles = [];
  }
}
