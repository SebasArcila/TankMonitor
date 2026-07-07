# 🚰 TankMonitor

Plataforma de monitoreo industrial en tiempo real para una planta de tratamiento de agua. Un simulador de PLC genera lecturas de sensores cada segundo, un backend en Go expone los datos a través de una API REST, y una aplicación cliente en Flutter los visualiza dinámicamente con actualización automática.

Este proyecto ha sido desarrollado como portafolio técnico, demostrando buenas prácticas de arquitectura backend en Go, persistencia con PostgreSQL y desarrollo frontend multiplataforma con Flutter.

---

## 🏗️ Arquitectura del Sistema

```text
┌─────────────────┐      Cada 1s       ┌──────────────┐
│  Simulador PLC   │ ─────Inserta─────▶│  PostgreSQL   │
│  (Goroutine Go)  │                    │  sensor_data  │
└─────────────────┘                    └──────┬───────┘
                                              │ Lee
                                              ▼
                                       ┌──────────────┐
                                       │   API REST   │
                                       │   (Gin/Go)   │
                                       │  /status     │
                                       │  /history    │
                                       └──────┬───────┘
                                              │ HTTP Polling (Cada 2s)
                                              ▼
                                       ┌──────────────┐
                                       │ App Flutter  │
                                       │ (Web/Móvil)  │
                                       └──────────────┘
```

**Decisión clave de diseño:** Desacoplamiento total entre el backend y el frontend mediante una API REST estándar. Esto permite extender o reemplazar el cliente web/móvil sin alterar la lógica de negocio ni el simulador del PLC.

---

## 🛠️ Stack Tecnológico

| Capa | Tecnología | Justificación |
|---|---|---|
| **Backend** | Go + Gin | Alto rendimiento, tipado fuerte y soporte nativo de concurrencia (goroutines) ideal para la simulación paralela del PLC. |
| **Base de Datos** | PostgreSQL + pgx | Motor relacional robusto. El driver `pgx/v5` ofrece una comunicación nativa extremadamente rápida y eficiente con PostgreSQL. |
| **Frontend** | Flutter (Dart) | Renderizado rápido y base de código única para Web, Android, iOS y Desktop. |
| **Gráficos** | `fl_chart` | Visualización de series temporales eficiente para datos históricos (Temperatura). |
| **Contenedores** | Docker + Compose | Entorno reproducible y fácil de desplegar en producción. |

---

## ✨ Funcionalidades Principales

- **Simulador de PLC Industrial**: Genera automáticamente datos aleatorios pero realistas para 4 variables clave: Temperatura, pH, Nivel de agua y Estado de la bomba de agua.
- **API REST Robusta**:
  - `GET /status` — Obtiene la lectura más reciente del tanque.
  - `GET /history?limit=N` — Devuelve las últimas N lecturas registradas (por defecto 20).
- **Aplicación Flutter Reactiva**:
  - Actualización automática en tiempo real mediante *HTTP Polling* cada 2 segundos.
  - Indicador visual de conexión en vivo (🟢 En vivo / 🔴 Sin conexión) para notificar problemas de red con el backend.
  - Panel gráfico dinámico que dibuja el histórico de temperatura.
  - Historial detallado de todas las lecturas de los sensores.
  - Resiliencia ante fallos: la app conserva en pantalla el último estado conocido si el backend se desconecta temporalmente.
- **Seguridad y CORS**: Configuración explícita de CORS en el backend que permite la comunicación fluida con clientes web remotos o locales.

---

## 🚀 Instrucciones de Ejecución

### Requisitos previos
- Go 1.22+
- Flutter SDK (versión 3.x)
- PostgreSQL instalado o Docker

---

### Opción A: Despliegue Rápido con Docker (Recomendado)

Docker Compose levantará de manera automática PostgreSQL y el Backend Go (con la base de datos y la tabla inicializadas automáticamente).

1. Ingresa a la carpeta del backend:
   ```bash
   cd backend
   ```
2. Inicia los servicios con Docker:
   ```bash
   docker compose up --build
   ```
3. Levanta la aplicación Flutter:
   ```bash
   cd ../flutter
   flutter pub get
   flutter run -d chrome
   ```

---

### Opción B: Ejecución Local Manual

#### 1. Configuración de Base de Datos
Ejecuta el archivo de esquema en tu base de datos local PostgreSQL:
```bash
cd database
psql -U postgres -f schema.sql
```
*Asegúrate de que la base de datos `tankmonitor` esté disponible en el puerto `5432` con usuario `postgres`.*

#### 2. Ejecutar el Backend en Go
1. Navega a la carpeta del backend:
   ```bash
   cd backend
   ```
2. Descarga las dependencias e inicia el servidor:
   ```bash
   go mod tidy
   go run main.go
   ```
El backend estará escuchando en `http://localhost:8080`.

#### 3. Ejecutar el Frontend en Flutter
1. Navega a la carpeta del frontend:
   ```bash
   cd flutter
   ```
2. Obtén los paquetes de Flutter y ejecuta la app:
   ```bash
   flutter pub get
   flutter run -d chrome    # Ejecutar en Google Chrome
   ```
> 💡 *Tip para Android*: Si usas un emulador Android, edita `baseUrl` en `lib/services/api_service.dart` reemplazando `localhost` por `10.0.2.2`.

---

## 📁 Estructura del Proyecto

```text
TankMonitor/
├── backend/     # Servidor API REST + simulador de PLC (Go)
├── database/    # Scripts de inicialización del esquema SQL (PostgreSQL)
├── docs/        # Documentación técnica ampliada del proyecto
├── flutter/     # Aplicación cliente multiplataforma (Flutter/Dart)
└── .gitignore   # Configuración de archivos excluidos en Git
```

---

## 📐 Decisiones de Arquitectura Relevantes

- **Mecanismo de Actualización**: Se utiliza *HTTP Polling* cada 2 segundos en lugar de WebSockets. Para la frecuencia de datos (1 inserción/segundo), el polling simplifica la infraestructura de red y mantiene el backend sin estado.
- **Tipos de Datos en DB**: Se utilizó `NUMERIC` en lugar de `FLOAT` en la base de datos para almacenar métricas clave (Temperatura, pH, Nivel) con precisión exacta, evitando los errores de precisión binaria comunes de coma flotante.
- **Contenedores de Compilación Multietapa (Multi-stage)**: El Dockerfile utiliza compilación multietapa. La imagen final de ejecución es ligera (~20MB) y contiene únicamente el binario compilado de Go sobre una base mínima de Alpine Linux.

---

## 🔮 Roadmap / Mejoras Futuras

- [ ] Implementar autenticación segura basada en JSON Web Tokens (JWT).
- [ ] Migrar el backend a WebSockets para actualizaciones push en tiempo real.
- [ ] Expandir el backend para soportar múltiples tanques en paralelo.
- [ ] Agregar un sistema de alertas automáticas (alertas vía e-mail/Slack si el pH o temperatura sobrepasan umbrales críticos).
- [ ] Integrar un gestor de estados avanzado en Flutter como Riverpod.

---

## 👥 Autor

Desarrollado por **Sebastian Arcila** como proyecto técnico y portafolio profesional centrado en tecnologías Go y Flutter.
