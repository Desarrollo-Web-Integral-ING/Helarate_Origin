import 'camera_access.dart';

/// En Android/iOS/escritorio el permiso se gestiona con permission_handler.
Future<CameraAccessResult> requestBrowserCamera() async =>
    const CameraAccessResult(CameraAccess.granted);
