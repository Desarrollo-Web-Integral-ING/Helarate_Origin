# Informe Técnico de Seguridad — Helarate



## Justificación de Almacenamiento Local (`localStorage`)

### Mecanismo utilizado

Helarate es una SPA construida en **Flutter Web**. La persistencia de sesión del SDK de `supabase_flutter` utiliza, por defecto en la plataforma web, el `localStorage` del navegador para almacenar el JWT (token de sesión) del usuario autenticado. Esto es un comportamiento estándar del SDK, no una decisión de implementación propia del proyecto.

### Medida que reduce la superficie de ataque

Flutter Web, en su modo de renderizado por defecto (**CanvasKit**, basado en **WebGL**), dibuja toda la interfaz sobre un único `<canvas>` en vez de generar un árbol de nodos DOM/HTML tradicional. Esto tiene una consecuencia relevante para la seguridad del `localStorage`:

- La mayoría de los ataques de **XSS (Cross-Site Scripting)** dependen de inyectar HTML/JavaScript ejecutable a través del DOM de la página (por ejemplo, mediante `innerHTML`, atributos de eventos, o campos de entrada mal sanitizados que se reflejan como HTML).
- Al no existir un árbol DOM tradicional donde inyectar marcado (la UI completa es un dibujo dentro de un `<canvas>`), se elimina buena parte de los vectores de inyección de XSS "clásicos" que normalmente se usarían para ejecutar `localStorage.getItem(...)` y exfiltrar el token de sesión.

### Limitación honesta de esta mitigación

Es importante no sobrevender esta medida en el reporte:

- **No es inmunidad absoluta.** El renderizado en `<canvas>` reduce la superficie de ataque frente a XSS *inyectado vía DOM*, pero no elimina el riesgo de XSS en general. Si un atacante logra ejecutar JavaScript arbitrario en el contexto de la página por *cualquier otra vía* (por ejemplo, una dependencia de terceros comprometida, un `<script>` cargado desde un CDN vulnerado, o una vulnerabilidad en el propio motor de Flutter Web), ese script sí podría leer `localStorage` sin ninguna barrera adicional, porque `localStorage` es accesible por cualquier JavaScript que corra en el origen (*origin*) de la página, sin importar cómo se dibuje la UI.
- El `localStorage` **no tiene el flag `HttpOnly`** (a diferencia de una cookie configurada correctamente), así que sigue siendo, por diseño, accesible desde JavaScript. La mitigación de CanvasKit reduce la *probabilidad de que exista un vector de inyección*, no cambia la naturaleza del almacenamiento en sí.
- Por lo tanto, la postura correcta para el reporte es: *"el uso de CanvasKit/WebGL reduce el vector de ataque XSS más común (inyección vía DOM), pero la mitigación real y verificable del riesgo residual descansa en buenas prácticas complementarias"*, entre ellas:
  - No renderizar HTML no confiable ni usar `dart:html` para insertar contenido dinámico sin sanitizar.
  - Mantener actualizadas las dependencias de `pubspec.yaml` (paquetes de terceros son el vector de inyección de script más realista en este contexto).
  - Expiración de sesión (JWT) con vida corta + *refresh token* rotativo, ya delegado al comportamiento por defecto de Supabase Auth.
  - Content Security Policy (CSP) a nivel de hosting (Vercel) restringiendo `script-src` a orígenes conocidos, como capa adicional independiente del motor de renderizado.

### Conclusión para el informe

> Helarate persiste el JWT de sesión en `localStorage` por ser el comportamiento estándar de `supabase_flutter` en Flutter Web. El uso del motor de renderizado CanvasKit (WebGL) reduce la superficie de ataque frente a XSS inyectado vía DOM, ya que la interfaz no se construye como árbol HTML tradicional. Esta medida **no constituye inmunidad** frente a XSS en general; el riesgo residual se gestiona con actualización de dependencias, ausencia de renderizado de HTML no confiable, y una futura política CSP a nivel de hosting.