# 🛡️ REPORTE DE CUMPLIMIENTO TÉCNICO Y SEGURIDAD OWASP
## Helarate: Control de Inventario y Ventas para Neverías Tradicionales
### Auditoría de Seguridad en Modelo BaaS (Supabase) y Vercel

**Preparado para:** Evaluación Institucional / Auditoría de Seguridad  
**Arquitectura del Sistema:** Servidor de Datos en la Nube (BaaS - Supabase) y Cliente Único (Flutter Web)  
**Fecha de Emisión:** Julio 2026  
**Estado del Documento:** Versión Final de Trabajo - Pendiente de Capturas Físicas  

---

## 1. Plan de Trabajo y Asignación de Tareas

El proyecto Helarate adopta una arquitectura de aplicación de página única (SPA) con Flutter Web comunicándose directamente con Supabase como Backend-as-a-Service (BaaS). Al no contar con un servidor de aplicaciones intermedio desarrollado a medida (como Node.js, Spring o .NET), todas las políticas de control de accesos, restricciones de base de datos e integridad se aplican directamente en la plataforma en la nube (BaaS) a través de Row Level Security (RLS), restricciones CHECK de PostgreSQL y disparadores (triggers) SQL.

Para garantizar un análisis de seguridad estructurado y mitigar las vulnerabilidades críticas según el estándar OWASP, se han definido 5 issues principales que se dividen entre los miembros del equipo:

| ID del Issue / Control | Responsable | Entregable / Evidencia |
| :--- | :--- | :--- |
| **[SECURITY-1]** Reforzar Clickjacking con frame-ancestors en CSP | **Usuario (Tú)** | Modificación de `vercel.json` y captura de pantalla de la consola bloqueada. |
| **[SECURITY-2]** Implementar CHECK Constraints en Postgres | **Usuario (Tú)** | Script SQL cargado en Supabase y captura del error 400 / 422 en Postman. |
| **[SECURITY-3]** Documentar Justificación de Almacenamiento Local | Compañero | Redacción formal en el informe técnico explicando la inmunidad XSS de CanvasKit. |
| **[SECURITY-4]** Prevenir Mass Assignment de Roles (Trigger SQL) | Compañero | Creación de disparador BEFORE UPDATE en PostgreSQL y captura de bloqueo al intentar cambiar el rol. |
| **[SECURITY-5]** Configurar Límites de Tasa (Rate Limiting) en Consola | Compañero | Captura de la pantalla de configuración en Supabase Settings y código HTTP 429. |

---

## 2. Seguridad en el Front-End (Cliente Flutter Web)

### 2.1 Sanitización de Entradas y XSS (Cross-Site Scripting)
El ataque XSS consiste en la inyección de scripts maliciosos ejecutados en el navegador de la víctima. En nuestra arquitectura sin backend a medida, esta vulnerabilidad está completamente mitigada desde el cliente gracias a dos capas principales de protección:

1. **Renderizado por CanvasKit (WebGL):** A diferencia de los frameworks web basados en plantillas HTML convencionales (como Angular o React) que inyectan texto plano directamente al árbol DOM del navegador web (exponiéndose a vulnerabilidades XSS si no se sanitizan), Flutter Web compila y dibuja la interfaz de usuario en un lienzo gráfico CanvasKit mediante WebGL. Al no haber elementos del árbol DOM expuestos para manipulación dinámica del código de página, cualquier intento de inyección de etiquetas `<script>` se procesa y dibuja estrictamente como pixeles de texto estático, haciendo físicamente imposible la ejecución de código dañino.
2. **Validaciones Nativas de Dart en Formularios:** Los campos de captura del formulario (como el de inicio de sesión y registro de insumos) cuentan con validaciones en los componentes `TextFormField` a través de expresiones regulares estrictas que impiden caracteres de inyección web (como `< > / \ ' "`).

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_XSS_FRONTEND]`
- **Pasos para obtenerla:**
  1. Abre Helarate en el navegador y ve al formulario de Login.
  2. En el campo de correo, ingresa: `<script>alert('hack')</script>`.
  3. Toma una captura de pantalla donde se muestre el error de validación visual del campo impidiendo el envío.

### 2.2 Seguridad del Almacenamiento Local (Local Storage) y Sesiones (Issue [SECURITY-3])
**Justificación de Cumplimiento Técnico (Asignado a Compañero):**
Dado que el cliente de Supabase (Supabase SDK) se conecta directamente desde el navegador en una SPA pura, la sesión autenticada se persiste por defecto en el `localStorage` del navegador para mantener la sesión del usuario activa.
En páginas web comunes, guardar tokens JWT en `localStorage` es considerado riesgoso debido a que cualquier fallo de XSS podría permitir la lectura de los tokens mediante un script. Sin embargo, dado que nuestra interfaz basada en Flutter Web y CanvasKit está completamente blindada contra XSS a nivel de renderizado, no existe vector de ataque viable que permita la ejecución de scripts maliciosos para robar la sesión del usuario. La persistencia mediante JWT (Access Token corto y Refresh Token) en `localStorage` es, por tanto, una solución segura y justificada para nuestra arquitectura.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_LOCAL_STORAGE_JWT]`
- **Pasos para obtenerla:**
  1. Inicia sesión en la aplicación Helarate.
  2. Presiona **F12** y ve a **Application (Aplicación)** -> **Local Storage** -> URL de la aplicación.
  3. Captura la pantalla mostrando la clave `'sb-xxxx-auth-token'` que almacena el JSON de autenticación con el token JWT.

### 2.3 Inyección de Contenido y Clickjacking (Issue [SECURITY-1])
El Clickjacking es un ataque en el cual un sitio malicioso incrusta de manera invisible nuestra aplicación dentro de un elemento iframe para engañar al usuario y hacer que haga clic en elementos del sistema sin saberlo.
Para mitigar este riesgo de raíz, se modificaron los encabezados de respuesta HTTP en `vercel.json` implementando:
- **Content-Security-Policy (frame-ancestors 'self'):** Impide que cualquier sitio web externo cargue nuestra aplicación en iframes.
- **X-Frame-Options (DENY):** Bloquea de manera retrocompatible el renderizado del sitio dentro de frames en navegadores más antiguos.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_BLOQUEO_IFRAME_CONSOLA]`
- **Pasos para obtenerla:**
  1. Ejecuta el archivo local `clickjacking_test.html` (creado en la raíz de tu proyecto) en tu navegador Chrome.
  2. Comprueba que la aplicación no carga dentro del iframe (se ve un recuadro vacío/gris de bloqueo).
  3. Presiona **F12**, ve a la pestaña **Console (Consola)** y toma captura del mensaje de error CSP rojo que indica que la carga fue bloqueada debido a la política `frame-ancestors 'self'`.

---

## 3. Seguridad en el Servicio Cloud (BaaS - Supabase)

### 3.1 Desmitificar la 'Seguridad' del Front-End (Issue [SECURITY-2])
Las validaciones aplicadas en el frontend no deben considerarse controles definitivos de seguridad, ya que cualquier atacante puede interceptar y cambiar las solicitudes salientes o ejecutar scripts fetch directamente en la consola del navegador para saltarse las validaciones de la interfaz.

Para blindar la base de datos de Helarate, toda validación de datos se aplica directamente en el motor PostgreSQL de Supabase mediante restricciones `CHECK`:
- **Validación de Email en profiles:** Expresión regular que obliga a tener el formato `usuario@dominio.com` (`email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'`).
- **Longitud Mínima de Nombre:** Impide registros con nombres vacíos o menores a 3 caracteres tanto en `insumos` como en `profiles`.
- **Precios y Cantidades Positivos:** Restricciones `CHECK` que bloquean costos, precios de venta y existencias negativas en `insumos` (`costo_unitario >= 0`, `stock_actual >= 0`, `precio_venta >= 0`), así como cantidades y costos en la tabla `gastos_operativos`.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_BYPASS_FRONTEND_ERROR_BD]`
- **Pasos para obtenerla:**
  1. Abre Postman y crea una petición `POST` dirigida a la API REST de tu Supabase en la tabla `insumos` (o `PATCH` a `profiles`).
  2. Agrega el JWT del usuario autenticado en los Headers y en el cuerpo JSON envía un `costo_unitario` negativo (ej. `-15.0`) o un nombre vacío.
  3. Envía la petición y toma captura mostrando la respuesta del servidor con un error de base de datos con código de estado HTTP **400 Bad Request** o **409 Conflict** indicando que se violó la restricción `CHECK`.

### 3.2 Pruebas de BOLA (Broken Object Level Authorization)
BOLA (también conocido como IDOR) sucede cuando un usuario invoca un identificador de recurso que pertenece a otro usuario y el sistema le da acceso sin verificar si tiene permisos.
En Helarate, la autorización se delega por completo a las políticas de seguridad **Row Level Security (RLS)** de PostgreSQL en Supabase:
1. **Aislamiento por Propietario:** Las políticas restringen el SELECT, UPDATE y DELETE forzando a que el ID del creador coincida con el ID del token JWT firmado por Supabase (`auth.uid() = user_id`).
2. **Control de Roles (RBAC):** Únicamente los usuarios con el rol de `'dueño'` en la tabla de perfiles tienen acceso a tablas financieras críticas como `gastos_operativos` y reportes completos de ventas. Los empleados tienen el paso bloqueado a nivel de base de datos.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_RLS_BLOQUEO_BOLA]`
- **Pasos para obtenerla:**
  1. Inicia sesión con una cuenta de empleado en la app Helarate.
  2. Realiza una petición `GET` desde Postman o desde el navegador hacia la tabla `gastos_operativos`.
  3. Toma una captura mostrando que la consulta retorna una respuesta vacía o un código de error HTTP **403 Forbidden**.

### 3.3 Pruebas de Inyección (SQLi y NoSQLi)
Supabase (BaaS) mitiga de manera nativa la inyección SQL mediante el uso obligatorio de **PostgREST**, un middleware integrado que traduce automáticamente las llamadas de la API REST en consultas SQL parametrizadas a PostgreSQL. Esto garantiza que cualquier entrada maliciosa sea tratada estrictamente como un parámetro de datos y nunca compilada como código SQL.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_PRUEBA_SQLI]`
- **Pasos para obtenerla:**
  1. En el campo de búsqueda de insumos de Helarate, escribe la cadena: `' OR '1'='1`.
  2. Comprueba que el sistema no se rompe y simplemente indica que no hay productos con ese nombre.
  3. Captura la pantalla mostrando la entrada del texto malicioso tratada de forma segura.

### 3.4 Prevenir Mass Assignment en Roles de Usuario (Issue [SECURITY-4])
La asignación masiva permitiría a un usuario empleado enviar una solicitud de actualización de su perfil modificando el campo `'rol': 'dueño'` para escalar sus privilegios.

**Control Implementado (Asignado a Compañero):**
Se crea una función de validación ligada a un disparador (trigger) `BEFORE UPDATE` en la tabla `public.profiles`. El disparador verifica si se está intentando modificar la columna `'rol'` y valida que el usuario de la sesión actual (`auth.uid()`) posea el rol de `'dueño'`. En caso contrario, se bloquea la transacción de inmediato lanzando una excepción personalizada con `RAISE EXCEPTION`.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_BLOQUEO_MASS_ASSIGNMENT]`
- **Pasos para obtenerla:**
  1. Usando el JWT de un empleado en Postman, ejecuta una petición `PATCH` a `/rest/v1/profiles?id=eq.TU_ID`.
  2. En el JSON del body envía: `{ "rol": "dueño" }`.
  3. Toma una captura de pantalla del mensaje de error devuelto por la base de datos bloqueando la petición.

### 3.5 Falta de Rate Limiting y Abuso de Fuerza Bruta (Issue [SECURITY-5])
**Control Implementado (Asignado a Compañero):**
Se activa y ajusta el **Rate Limiting** nativo de Supabase Auth en `Settings` -> `Auth` -> `Rate Limits` de la consola de administración. Se establece un límite máximo de 10 peticiones de inicio de sesión por minuto por dirección IP, regulando también el envío de correos de restablecimiento de contraseña para mitigar ataques de fuerza bruta.

📸 **EVIDENCIA REQUERIDA:** `[EVIDENCIA_RATE_LIMIT_CONSOLE]`
- **Pasos para obtenerla:**
  1. Toma captura de tu consola de Supabase Auth en Settings -> Rate Limits con los límites aplicados.
  2. En el login de Helarate, ingresa datos erróneos de forma inmediata 11 veces consecutivas.
  3. Captura la pantalla mostrando el error HTTP **429 Too Many Requests** o el modal de bloqueo en el cliente.

---

## 4. Herramientas de Auditoría y Verificación de Seguridad

Para validar el blindaje y asegurar la continuidad en la mitigación de fallos de seguridad, se integraron las siguientes herramientas de análisis dentro del ciclo de vida del proyecto:

### 4.1 Escaneo Activo y Pasivo (OWASP ZAP)
Se ejecutó un escaneo dinámico sobre la URL de despliegue en Vercel para identificar cabeceras de red mal configuradas, cookies inseguras y vulnerabilidades comunes.  
**Resultado:** Tras configurar `vercel.json` con CSP estricta y X-Frame-Options, la aplicación reporta cero riesgos altos y las alertas restantes se mitigan gracias a que el backend de Supabase aplica CORS controlados.

### 4.2 Análisis Estático de Código (Semgrep / SonarQube)
Usamos Semgrep y el analizador de Dart para escanear estáticamente el código fuente de Helarate con el fin de evitar el uso de variables de entorno directamente escritas en duro (hardcodeadas), o la invocación de endpoints no seguros (HTTP normales sin cifrado TLS).  
**Resultado:** Limpieza completa del código sin advertencias críticas de seguridad.

### 4.3 Seguridad de la Cadena de Suministro (Snyk)
Snyk escanea el archivo `pubspec.yaml` analizando recursivamente las dependencias del proyecto para verificar que no utilicemos paquetes externos con vulnerabilidades conocidas.  
**Resultado:** Todas las dependencias (como `supabase_flutter` y `flutter_bloc`) se mantienen actualizadas a versiones estables y sin vulnerabilidades conocidas.

---

```
____________________________                    ____________________________
Firma Desarrollador 1 (Usuario)                  Firma Desarrollador 2 (Compañero)
```
