import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'camera_access.dart';

/// Pide la cámara directamente al navegador con getUserMedia. Es lo que hace
/// que aparezca el aviso "¿Permitir que este sitio use la cámara?" y permite
/// saber exactamente por qué falla si no aparece.
Future<CameraAccessResult> requestBrowserCamera() async {
  // Fuera de un contexto seguro (http en lugar de https/localhost) el
  // navegador no ofrece mediaDevices.
  final nav = web.window.navigator as JSObject;
  final md = nav.getProperty<JSAny?>('mediaDevices'.toJS);
  if (md == null || md.isUndefinedOrNull || !web.window.isSecureContext) {
    return const CameraAccessResult(
      CameraAccess.insecure,
      'mediaDevices no disponible (¿http sin localhost?)',
    );
  }

  // ¿La cabecera Permissions-Policy del servidor prohíbe la cámara? En ese caso
  // el navegador la niega sin mostrar ningún aviso de permiso.
  try {
    final doc = web.document as JSObject;
    var pp = doc.getProperty<JSAny?>('permissionsPolicy'.toJS);
    if (pp == null || pp.isUndefinedOrNull) {
      pp = doc.getProperty<JSAny?>('featurePolicy'.toJS);
    }
    if (pp != null && !pp.isUndefinedOrNull) {
      final allowed = (pp as JSObject)
          .callMethod<JSBoolean>('allowsFeature'.toJS, 'camera'.toJS)
          .toDart;
      if (!allowed) {
        return const CameraAccessResult(
          CameraAccess.blockedByPolicy,
          'Permissions-Policy: camera no permitida por el servidor',
        );
      }
    }
  } catch (_) {}

  final devices = web.window.navigator.mediaDevices;
  // ¿Hay alguna cámara? (una PC de escritorio sin webcam no muestra aviso)
  try {
    final list = (await devices.enumerateDevices().toDart).toDart;
    final cams = list.where((d) => d.kind == 'videoinput').length;
    if (cams == 0) {
      return const CameraAccessResult(
        CameraAccess.noDevice,
        'enumerateDevices: 0 cámaras',
      );
    }
  } catch (_) {
    // Si no se puede enumerar, se intenta pedir la cámara igualmente.
  }

  try {
    final stream = await devices
        .getUserMedia(web.MediaStreamConstraints(video: true.toJS))
        .toDart;
    // Solo queríamos el permiso: se libera la cámara para que la use el lector.
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
    return const CameraAccessResult(CameraAccess.granted);
  } catch (e) {
    final s = e.toString();
    if (s.contains('NotAllowedError') || s.contains('PermissionDenied')) {
      return CameraAccessResult(CameraAccess.denied, s);
    }
    if (s.contains('NotFoundError') || s.contains('DevicesNotFound')) {
      return CameraAccessResult(CameraAccess.noDevice, s);
    }
    if (s.contains('NotReadableError') || s.contains('TrackStartError')) {
      return CameraAccessResult(CameraAccess.inUse, s);
    }
    if (s.contains('SecurityError')) {
      return CameraAccessResult(CameraAccess.insecure, s);
    }
    return CameraAccessResult(CameraAccess.unknown, s);
  }
}
