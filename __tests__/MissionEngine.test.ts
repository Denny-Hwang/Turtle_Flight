import { MissionEngine } from '../src/core/mission/MissionEngine';

describe('MissionEngine', () => {
  let engine: MissionEngine;

  beforeEach(() => {
    engine = new MissionEngine();
  });

  test('loadStage sets correct state', () => {
    engine.loadStage(1);
    const state = engine.getState();
    expect(state.stageId).toBe(1);
    expect(state.objectivesTotal).toBe(10);
    expect(state.objectivesCompleted).toBe(0);
    expect(state.isComplete).toBe(false);
  });

  test('completeObjective increments count', () => {
    engine.loadStage(1);
    engine.completeObjective();
    engine.completeObjective();
    expect(engine.getState().objectivesCompleted).toBe(2);
  });

  test('completing all objectives marks stage complete', () => {
    engine.loadStage(1);
    for (let i = 0; i < 10; i++) engine.completeObjective();
    expect(engine.getState().isComplete).toBe(true);
  });

  test('getResult returns 3 stars for fast completion', () => {
    engine.loadStage(1);
    // Simulate 30 seconds elapsed
    for (let i = 0; i < 30; i++) engine.update(1);
    for (let i = 0; i < 10; i++) engine.completeObjective();
    const result = engine.getResult();
    expect(result).not.toBeNull();
    expect(result!.stars).toBe(3);
  });

  test('getResult returns 1 star for slow completion', () => {
    engine.loadStage(1);
    for (let i = 0; i < 150; i++) engine.update(1);
    for (let i = 0; i < 10; i++) engine.completeObjective();
    const result = engine.getResult();
    expect(result).not.toBeNull();
    expect(result!.stars).toBe(1);
  });

  test('reset clears state', () => {
    engine.loadStage(1);
    engine.completeObjective();
    engine.reset();
    expect(engine.getState().stageId).toBe(0);
  });
});
