export interface StageResult {
  stageId: number;
  completed: boolean;
  stars: 0 | 1 | 2 | 3;
  timeSeconds: number;
  objectivesCompleted: number;
  totalObjectives: number;
}
