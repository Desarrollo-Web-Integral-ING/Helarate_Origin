/// Resultado de pedir la cámara al navegador.
enum CameraAccess {
  /// Permiso concedido (o no aplica en esta plataforma).
  granted,

  /// El usuario (o el navegador/IDE) negó el permiso.
  denied,

  /// El equipo no tiene ninguna cámara conectada.
  noDevice,

  /// La cámara existe pero otra aplicación la está usando.
  inUse,

  /// Página no segura: el navegador solo permite la cámara en HTTPS/localhost.
  insecure,

  /// El servidor del sitio prohíbe la cámara (cabecera Permissions-Policy).
  blockedByPolicy,

  /// Cualquier otro fallo.
  unknown,
}

class CameraAccessResult {
  final CameraAccess access;

  /// Texto técnico del error, útil para diagnosticar.
  final String? detail;

  const CameraAccessResult(this.access, [this.detail]);

  bool get ok => access == CameraAccess.granted;
}
