# Helarate 🍦

Helarate es un sistema de control de inventario y ventas diseñado específicamente para neverías tradicionales. Permite registrar las ventas del día, llevar el control del stock de insumos (cucharas, vasos, bolsas) y sabores de nieve, además de visualizar analíticas e ingresos financieros en tiempo real.

---

## 🏗️ Arquitectura del Sistema

El proyecto adopta una **Arquitectura Limpia (Clean Architecture)** adaptada a un modelo **BaaS (Backend as a Service)** con **Supabase** como proveedor de base de datos, autenticación y seguridad en la nube.

La estructura de carpetas en `lib/` está organizada por capas de la siguiente manera:

*   **`core/`**: Capa transversal que contiene configuraciones compartidas, constantes, utilidades, temas visuales y widgets globales compartidos.
*   **`domain/`**: Capa pura de negocio. Contiene las entidades o modelos de datos (`ProductoProduccion`, `ProductoVenta`, `Venta`) y las definiciones abstractas (interfaces/contratos) de los repositorios. No depende de ningún framework o base de datos.
*   **`data/`**: Capa de datos. Contiene las implementaciones de los repositorios, llamadas al cliente de Supabase (o persistencia local en `SharedPreferences` para desarrollo/pruebas) y servicios externos.
*   **`presentation/`**: Capa visual. Contiene las pantallas (screens), widgets específicos de la UI y los bloques de estado (BLoCs) para reaccionar a las interacciones del usuario.

### Estructura de Carpetas
```text
lib/
├── core/
│   ├── theme/          # Estilos y gradientes globales
│   └── widgets/        # Widgets generales de la app (ej. controladores de navegación)
├── data/
│   └── services/       # Implementaciones de persistencia local y remota
├── domain/
│   └── models/         # Modelos de datos / Entidades
├── presentation/
│   ├── screens/        # Vistas de la aplicación (Dashboard, Ventas, Insumos, etc.)
│   └── widgets/        # Componentes UI de pantalla (tarjetas de estadísticas, etc.)
└── main.dart           # Inicializador y punto de entrada
```

---

## 🛠️ Tecnologías Utilizadas

*   **Frontend**: Flutter & Dart (Multiplataforma: Android, iOS y Web).
*   **Gestión de Estado**: Patrón BLoC (`flutter_bloc`).
*   **Localizador de Servicios**: GetIt (`get_it`).
*   **Enrutamiento**: GoRouter (`go_router`).
*   **Backend & Base de Datos**: Supabase (PostgreSQL en la nube).
*   **Autenticación**: Supabase Auth (Manejo de sesiones y roles JWT).
*   **Seguridad**: Row Level Security (RLS) a nivel de base de datos.

---

## 🗺️ Roadmap de Desarrollo (Sprints)

### 🏗️ Pre-Sprint (Actual)
*   [x] Estructurar carpetas en Arquitectura Limpia (`core`, `domain`, `data`, `presentation`).
*   [x] Habilitar la plataforma Flutter Web.
*   [ ] Crear repositorio y configurar ramas iniciales en Git.

### 🟦 Sprint 1: Conexión de Datos (Supabase)
*   [ ] Configurar base de datos en Supabase y tablas PostgreSQL (`insumos`, `ventas`, `detalle_venta`, `gastos_operativos`, `profiles`).
*   [ ] Escribir Triggers PostgreSQL para decrementar stock y auditar movimientos de inventario de forma automática.
*   [ ] Implementar el cliente de Supabase en Flutter.
*   [ ] Migrar pantallas a los patrones `Repository` y `BLoC`, desconectando el almacenamiento local.

### 🟨 Sprint 2: Optimización Web y Despliegue
*   [ ] Adaptar la interfaz para que sea responsiva (sidebar en web / menú inferior en móvil).
*   [ ] Configurar CORS en Supabase para permitir consultas locales y de producción.
*   [ ] Crear pipeline de Integración Continua (GitHub Actions).
*   [ ] Desplegar la versión Web automáticamente con Vercel y SSL (HTTPS).

### 🟥 Sprint 3: Autenticación y Seguridad (RBAC)
*   [ ] Configurar Supabase Auth con credenciales (Email/Password).
*   [ ] Crear una pantalla de login responsiva.
*   [ ] Proteger rutas mediante `go_router` según el rol de usuario (dueño vs. empleado).
*   [ ] Habilitar Row Level Security (RLS) en la base de datos para restringir accesos financieros a empleados.

---

## 🚀 Instalación y Ejecución Local

### Prerrequisitos
*   Flutter SDK (v3.0.0 o superior)
*   Dart SDK

### Instrucciones
1.  Clona el repositorio:
    ```bash
    git clone <url-del-repositorio>
    cd nevero_app
    ```
2.  Obtén las dependencias:
    ```bash
    flutter pub get
    ```
3.  Ejecuta el analizador para validar que no haya errores:
    ```bash
    flutter analyze
    ```
4.  Arranca la aplicación:
    *   **Móvil (Android/iOS)**:
        ```bash
        flutter run
        ```
    *   **Web (Chrome)**:
        ```bash
        flutter run -d chrome
        ```
