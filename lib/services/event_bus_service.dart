import 'package:event_bus/event_bus.dart';

// Global EventBus instance
final EventBus eventBus = EventBus();

// Event classes for file access permissions
class FileAccessRequestEvent {
  final String requesterId;
  final String requesterName;
  
  FileAccessRequestEvent({required this.requesterId, required this.requesterName});
}

class FileAccessGrantedEvent {
  final String deviceId;
  
  FileAccessGrantedEvent({required this.deviceId});
}

class FileAccessDeniedEvent {
  final String deviceId;
  
  FileAccessDeniedEvent({required this.deviceId});
}

class FileRequestEvent {
  final String requesterId;
  final String requesterName;
  final String filename;

  FileRequestEvent({
    required this.requesterId, 
    required this.requesterName,
    required this.filename,
  });
}