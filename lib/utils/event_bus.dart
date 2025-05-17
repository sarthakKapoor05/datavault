import 'package:event_bus/event_bus.dart';

final eventBus = EventBus();

class DeviceNameChangedEvent {
  final String newName;
  DeviceNameChangedEvent(this.newName);
}