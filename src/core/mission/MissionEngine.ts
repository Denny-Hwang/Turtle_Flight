import { StageDefinition, STAGES } from './StageDefinitions';
import { StageResult } from '../../models/StageResult';

export interface MissionState {
  stageId: number;
  objectivesCompleted: number;
  objectivesTotal: number;
  elapsedTime: number;
  isComplete: boolean;
}

export class MissionEngine {
  private stage: StageDefinition | null = null;
  private objectivesCompleted = 0;
  private elapsedTime = 0;
  private isComplete = false;

  loadStage(stageId: number): void {
    this.stage = STAGES.find((s) => s.id === stageId) || null;
    this.objectivesCompleted = 0;
    this.elapsedTime = 0;
    this.isComplete = false;
  }

  update(dt: number): MissionState {
    if (!this.stage || this.isComplete) {
      return this.getState();
    }
    this.elapsedTime += dt;
    return this.getState();
  }

  completeObjective(): void {
    if (!this.stage || this.isComplete) return;
    this.objectivesCompleted++;
    if (this.objectivesCompleted >= this.stage.objectiveCount) {
      this.isComplete = true;
    }
  }

  getResult(): StageResult | null {
    if (!this.stage || !this.isComplete) return null;

    let stars: 0 | 1 | 2 | 3 = 0;
    const t = this.elapsedTime;
    const th = this.stage.starThresholds;
    if (t <= th.three) stars = 3;
    else if (t <= th.two) stars = 2;
    else if (t <= th.one) stars = 1;

    return {
      stageId: this.stage.id,
      completed: true,
      stars,
      timeSeconds: this.elapsedTime,
      objectivesCompleted: this.objectivesCompleted,
      objectivesTotal: this.stage.objectiveCount,
    };
  }

  getState(): MissionState {
    return {
      stageId: this.stage?.id || 0,
      objectivesCompleted: this.objectivesCompleted,
      objectivesTotal: this.stage?.objectiveCount || 0,
      elapsedTime: this.elapsedTime,
      isComplete: this.isComplete,
    };
  }

  reset(): void {
    this.stage = null;
    this.objectivesCompleted = 0;
    this.elapsedTime = 0;
    this.isComplete = false;
  }
}
