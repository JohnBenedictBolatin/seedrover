enum RoverMovementCommand {
  forward,
  backward,
  rotateLeft,
  rotateRight,
  stop,
}

extension RoverMovementCommandLabel on RoverMovementCommand {
  String get label {
    return switch (this) {
      RoverMovementCommand.forward => 'Forward',
      RoverMovementCommand.backward => 'Backward',
      RoverMovementCommand.rotateLeft => 'Rotate Left',
      RoverMovementCommand.rotateRight => 'Rotate Right',
      RoverMovementCommand.stop => 'Stop',
    };
  }

  String get protocolCommand {
    return switch (this) {
      RoverMovementCommand.forward => 'MOVE_FORWARD',
      RoverMovementCommand.backward => 'MOVE_BACKWARD',
      RoverMovementCommand.rotateLeft => 'TURN_LEFT',
      RoverMovementCommand.rotateRight => 'TURN_RIGHT',
      RoverMovementCommand.stop => 'STOP',
    };
  }
}

enum PlantingCommand {
  start,
  pause,
  resume,
  stop,
}

extension PlantingCommandLabel on PlantingCommand {
  String get label {
    return switch (this) {
      PlantingCommand.start => 'Start',
      PlantingCommand.pause => 'Pause',
      PlantingCommand.resume => 'Resume',
      PlantingCommand.stop => 'Stop',
    };
  }

  String get protocolCommand {
    return switch (this) {
      PlantingCommand.start => 'START_PLANTING',
      PlantingCommand.pause => 'PAUSE_PLANTING',
      PlantingCommand.resume => 'RESUME_PLANTING',
      PlantingCommand.stop => 'STOP_PLANTING',
    };
  }
}

enum PlantingSeedType {
  calamansi,
  sitaw,
  peanut,
}

extension PlantingSeedTypeLabel on PlantingSeedType {
  String get label {
    return switch (this) {
      PlantingSeedType.calamansi => 'Calamansi',
      PlantingSeedType.sitaw => 'Sitaw',
      PlantingSeedType.peanut => 'Peanut',
    };
  }

  String get payloadValue {
    return switch (this) {
      PlantingSeedType.calamansi => 'calamansi',
      PlantingSeedType.sitaw => 'sitaw',
      PlantingSeedType.peanut => 'peanut',
    };
  }
}
