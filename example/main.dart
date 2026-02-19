import 'package:logging/logging.dart';
import 'package:small_fsm/small_fsm.dart';

// Adapter to bridge StateMachineLogger with package:logging
class LoggingAdapter implements StateMachineLogger {
  final Logger _logger;
  
  LoggingAdapter(this._logger);
  
  @override
  void logTransition(String event, String fromState, String toState) {
    _logger.info('[$event] $fromState -> $toState');
  }
}

final logger = Logger('fsm');

enum State { water, ice, steam }

enum Event { heat, cool }

int currentTemp = 0;

final fsm = StateMachine<State, Event>(
  initialState: State.water,
  logger: LoggingAdapter(logger),
  transitions: {
    State.water: [
      Transition(State.ice, Event.cool),
      Transition(State.steam, Event.heat),
    ],
    State.ice: [
      Transition(State.steam, Event.heat, guard: () => currentTemp >= 100),
      Transition(State.water, Event.heat),
    ],
    State.steam: [
      Transition(State.water, Event.cool,
          onTransition: () => logger.info('Liquefied')),
    ],
  },
  onEnter: {
    State.steam: () => logger.info('The water is boiling'),
    State.ice: () => logger.info('The water is frozen'),
  },
  onExit: {
    State.steam: () => logger.info('The water has stopped boiling'),
    State.ice: () => logger.info('The water has defrosted'),
  },
);

void main() {
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  final result1 = fsm.fire(Event.cool);
  logger.info('Transition ${fsm.state} (was water) allowed: $result1');
  
  final result2 = fsm.fire(Event.heat);
  logger.info('Transition ${fsm.state} (was ice) allowed: $result2');
  
  final result3 = fsm.fire(Event.heat);
  logger.info('Transition ${fsm.state} (was water) allowed: $result3');
  
  final result4 = fsm.fire(Event.cool);
  logger.info('Transition ${fsm.state} (was steam) allowed: $result4');
  
  final result5 = fsm.fire(Event.heat);
  logger.info('Transition ${fsm.state} (was water, temp=$currentTemp) blocked: $result5');
  
  currentTemp = 100;
  final result6 = fsm.fire(Event.heat);
  logger.info('Transition ${fsm.state} (was steam, temp=100) allowed: $result6');
  
  logger.info('Final state: ${fsm.state}');
}