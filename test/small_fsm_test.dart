import 'package:test/test.dart';

import 'package:small_fsm/small_fsm.dart';

enum State { steam, water, ice }

enum Event { freeze, melt, evaporate, condense }

/// A test logger that captures log messages for verification.
class TestLogger implements StateMachineLogger {
  final List<String> logs = [];

  @override
  void logTransition(String event, String fromState, String toState) {
    logs.add('[$event] $fromState -> $toState');
  }

  void clear() => logs.clear();
}

void main() {
  test('Simple transitions work', () {
    final fsm = FSM<State, Event>(
      initialState: State.water,
      transitions: const {
        State.steam: [
          Transition(State.water, Event.freeze),
        ],
        State.water: [
          Transition(State.steam, Event.evaporate),
          Transition(State.ice, Event.freeze),
        ],
        State.ice: [
          Transition(State.water, Event.melt),
        ],
      },
    );

    expect(fsm.state, State.water);

    fsm.fire(Event.freeze);
    expect(fsm.state, State.ice);

    fsm.fire(Event.evaporate);
    expect(fsm.state, State.ice);

    fsm.fire(Event.melt);
    expect(fsm.state, State.water);
  });

  test('fire returns true when transition succeeds', () {
    final fsm = FSM<State, Event>(
      initialState: State.water,
      transitions: const {
        State.water: [
          Transition(State.ice, Event.freeze),
        ],
      },
    );

    expect(fsm.fire(Event.freeze), true);
    expect(fsm.state, State.ice);
  });

  test('fire returns false when no transition exists', () {
    final fsm = FSM<State, Event>(
      initialState: State.water,
      transitions: const {
        State.water: [
          Transition(State.ice, Event.freeze),
        ],
      },
    );

    expect(fsm.fire(Event.melt), false);
    expect(fsm.state, State.water);
  });

  test('fire returns false when guard prevents transition', () {
    final fsm = FSM<State, Event>(
      initialState: State.water,
      transitions: {
        State.water: [
          Transition(State.ice, Event.freeze, guard: () => false),
        ],
      },
    );

    expect(fsm.fire(Event.freeze), false);
    expect(fsm.state, State.water);
  });

  test('Test guard function', () {
    final fsm = FSM<State, Event>(
      initialState: State.ice,
      transitions: {
        State.ice: [
          Tx(State.water, Event.evaporate, guard: () => false),
          Tx(State.steam, Event.evaporate, guard: () => true),
        ],
      },
    );

    expect(fsm.state, State.ice);

    fsm.fire(Event.evaporate);
    expect(fsm.state, State.steam);
  });

  test('Test callback function', () {
    var triggered = false;

    final fsm = FSM<State, Event>(
      initialState: State.ice,
      transitions: {
        State.ice: [
          Tx(State.water, Event.evaporate, onTransition: () {
            triggered = true;
          }),
        ],
      },
    );

    expect(fsm.state, State.ice);
    expect(triggered, false);

    fsm.fire(Event.evaporate);
    expect(fsm.state, State.water);
    expect(triggered, true);
  });

  test('Test transition stream', () async {
    var triggered = false;

    final fsm = FSM<State, Event>(
      initialState: State.ice,
      transitions: const {
        State.ice: [
          Tx(State.water, Event.evaporate),
        ],
      },
    );

    fsm.onTransition.listen((event) {
      expect(event.previousState, State.ice);
      expect(event.newState, State.water);
      expect(event.event, Event.evaporate);
      triggered = true;
    });

    expect(fsm.state, State.ice);
    expect(triggered, false);

    fsm.fire(Event.evaporate);
    expect(fsm.state, State.water);

    await Future.delayed(const Duration(milliseconds: 100));
    expect(triggered, true);
  });

  test('Test logger', () {
    final testLogger = TestLogger();

    final fsm = FSM<State, Event>(
      logger: testLogger,
      initialState: State.ice,
      transitions: const {
        State.ice: [
          Tx(State.water, Event.evaporate),
        ],
      },
    );

    fsm.fire(Event.evaporate);
    expect(fsm.state, State.water);

    expect(testLogger.logs, ['[evaporate] ice -> water']);
  });

  test('Test logger with multiple transitions', () {
    final testLogger = TestLogger();

    final fsm = FSM<State, Event>(
      logger: testLogger,
      initialState: State.ice,
      transitions: const {
        State.ice: [
          Tx(State.water, Event.melt),
        ],
        State.water: [
          Tx(State.steam, Event.evaporate),
        ],
      },
    );

    fsm.fire(Event.melt);
    expect(fsm.state, State.water);
    
    fsm.fire(Event.evaporate);
    expect(fsm.state, State.steam);

    expect(testLogger.logs, [
      '[melt] ice -> water',
      '[evaporate] water -> steam',
    ]);
  });

  test('Test onEnter callback', () {
    var enteredWater = false;
    var enteredIce = false;

    final fsm = FSM<State, Event>(
      initialState: State.steam,
      transitions: const {
        State.steam: [
          Tx(State.water, Event.condense),
        ],
        State.water: [
          Tx(State.ice, Event.freeze),
        ],
      },
      onEnter: {
        State.water: () => enteredWater = true,
        State.ice: () => enteredIce = true,
      },
    );

    // Initial state doesn't trigger onEnter
    expect(enteredWater, false);
    expect(enteredIce, false);

    fsm.fire(Event.condense);
    expect(enteredWater, true);
    expect(enteredIce, false);

    fsm.fire(Event.freeze);
    expect(enteredIce, true);
  });

  test('Test onExit callback', () {
    var exitedWater = false;
    var exitedIce = false;

    final fsm = FSM<State, Event>(
      initialState: State.water,
      transitions: const {
        State.water: [
          Tx(State.ice, Event.freeze),
        ],
        State.ice: [
          Tx(State.steam, Event.evaporate),
        ],
      },
      onExit: {
        State.water: () => exitedWater = true,
        State.ice: () => exitedIce = true,
      },
    );

    fsm.fire(Event.freeze);
    expect(exitedWater, true);
    expect(exitedIce, false);

    fsm.fire(Event.evaporate);
    expect(exitedIce, true);
  });
}