export interface StageDefinition {
  id: number;
  difficulty: number;
  type: 'rings' | 'maze' | 'valley' | 'peaks' | 'race';
  objectiveCount: number;
  starThresholds: { one: number; two: number; three: number };
}

export const STAGES: StageDefinition[] = [
  { id: 1, difficulty: 1, type: 'rings', objectiveCount: 10, starThresholds: { one: 180, two: 120, three: 60 } },
  { id: 2, difficulty: 2, type: 'maze', objectiveCount: 1, starThresholds: { one: 240, two: 150, three: 90 } },
  { id: 3, difficulty: 3, type: 'valley', objectiveCount: 1, starThresholds: { one: 300, two: 180, three: 100 } },
  { id: 4, difficulty: 4, type: 'peaks', objectiveCount: 7, starThresholds: { one: 360, two: 240, three: 120 } },
  { id: 5, difficulty: 5, type: 'race', objectiveCount: 1, starThresholds: { one: 300, two: 200, three: 120 } },
];
