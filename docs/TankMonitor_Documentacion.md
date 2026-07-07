# TankMonitor — Documento Maestro del Proyecto

> Este documento existe para que el desarrollo pueda continuar sin pérdida de contexto,
> con cualquier asistente de IA o incluso sin ninguno. Contiene todo lo decidido hasta
> ahora, el por qué de cada decisión, y el roadmap completo.

---

## 1. Visión del proyecto

**Nombre:** TankMonitor

**Objetivo:** Plataforma de monitoreo industrial para una planta de tratamiento de agua,
pensada como **proyecto de portafolio profesional** para entrevistas de trabajo (no es un
proyecto universitario, debe verse y comportarse como un producto real).

**Objetivo de aprendizaje del desarrollador:** Convertirse en desarrollador Backend con
conocimientos sólidos de Go y Flutter, entendiendo cada línea de código escrita, no solo
copiando y pegando.

**Filosofía de trabajo:**
- Explicar el concepto antes de escribir código.
- Presentar alternativas y sus ventajas/desventajas antes de decidir.
- Comentar el código con fines didácticos (qué es un package, struct, interface, pointer, etc.)
- Seguir Clean Code, SOLID, KISS, DRY, arquitectura limpia y buenas prácticas idiomáticas
  de Go y Flutter.
- Avanzar de forma incremental: nada de complejidad prematura.

---

## 2. Stack tecnológico

### Backend
- **Go** (lenguaje principal)
- **PostgreSQL** (base de datos)
- **pgx** (driver/pool de conexión a PostgreSQL, en su versión v5)
- Más adelante: **Gin** (framework HTTP), **JWT** (autenticación), **Docker** (contenedores)

### Frontend
- **Flutter / Dart**
- Más adelante: **Riverpod** (manejo de estado), **Dio** (cliente HTTP), **fl_chart** (gráficas)

### Explícitamente NO usar en la v1
APIs REST, IA, Docker, JWT, WebSockets, microservicios, arquitecturas complejas.
La v1 es deliberadamente simple.

---

## 3. Funcionamiento del sistema (v1)

Existe un **único tanque físico** (simulado). Se monitorean 4 variables:

| Variable | Descripción |
|---|---|
| `temperature` | Temperatura del agua |
| `ph` | Nivel de pH del agua |
| `level` | Nivel del tanque |
| `pump` | Estado de la bomba (encendida/apagada) |

Un programa en Go actúa como **simulador de un PLC** (Programmable Logic Controller,
el tipo de dispositivo industrial real que mediría estos valores). Cada segundo:
1. Genera valores aleatorios pero realistas para las 4 variables.
2. Los inserta en PostgreSQL.

Flutter, más adelante, mostrará:
1. Estado actual (última lectura).
2. Historial (lecturas pasadas).
3. Gráficas (con `fl_chart`, en una fase posterior).

---

## 4. Estructura de carpetas

```
TankMonitor/
├── backend/
│   ├── go.mod              # Define el módulo Go y sus dependencias
│   ├── go.sum               # Checksums de las dependencias (se genera automático)
│   └── main.go               # Punto de entrada: simulador del PLC
├── database/
│   └── schema.sql            # Definición de la base de datos y tablas
├── flutter/
│   └── (app Flutter, se crea en una fase posterior)
└── docs/
    └── TankMonitor_Documentacion.md   # Este archivo
```

**Por qué esta separación:** el esquema SQL es independiente del lenguaje del backend
(separación de responsabilidades a nivel de repositorio). La carpeta `docs/` centraliza
las decisiones de arquitectura para que cualquier nuevo desarrollador (o IA) entienda el
proyecto sin tener que leer todo el código primero.

---

## 5. Base de datos

**Nombre de la base de datos:** `tankmonitor`

**Tabla:** `sensor_data`

```sql
CREATE DATABASE tankmonitor;

\c tankmonitor

CREATE TABLE sensor_data (
    id SERIAL PRIMARY KEY,
    temperature NUMERIC(5,2) NOT NULL,
    ph NUMERIC(4,2) NOT NULL,
    level NUMERIC(5,2) NOT NULL,
    pump BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Justificación de tipos de datos

| Campo | Tipo | Por qué |
|---|---|---|
| `id` | `SERIAL PRIMARY KEY` | Autoincremental, identifica cada lectura de forma única |
| `temperature` | `NUMERIC(5,2)` | Decimal exacto (sin errores de redondeo binario), hasta 999.99 |
| `ph` | `NUMERIC(4,2)` | El pH va de 0 a 14, con 2 decimales es más que suficiente |
| `level` | `NUMERIC(5,2)` | Igual razonamiento que `temperature` |
| `pump` | `BOOLEAN NOT NULL` | Solo dos estados posibles: encendida/apagada |
| `created_at` | `TIMESTAMP NOT NULL DEFAULT NOW()` | Se autocompleta con la fecha/hora del servidor al insertar |

### Mejoras pendientes (no implementadas aún, a propósito)
- Índice en `created_at` para acelerar consultas de historial ordenadas por fecha.
- Posible cambio a `TIMESTAMPTZ` si el sistema opera en múltiples zonas horarias.
- `CHECK constraint` para validar que `ph` esté entre 0 y 14.

---

## 6. Backend Go — Estado actual y diseño

### Decisiones de diseño
- Usamos `pgx/v5` con `pgxpool` (pool de conexiones) en lugar de `database/sql` +
  driver genérico, porque `pgx` es el driver nativo y más eficiente para PostgreSQL en Go,
  y expone directamente características de Postgres sin capas de abstracción extra.
- Sin frameworks HTTP todavía (Gin llega después). El programa es un simple bucle que
  simula el PLC y escribe a la base de datos.
- Sin goroutines/concurrencia todavía (se mantiene simple a propósito, principio KISS).
  Se introducirán cuando agreguemos el servidor HTTP para no mezclar demasiados
  conceptos nuevos a la vez.

### Comando para agregar la dependencia pgx
```bash
cd backend
go get github.com/jackc/pgx/v5/pgxpool
```

### Conceptos de Go cubiertos hasta ahora
- **package**: unidad de organización de código en Go. Todo archivo `.go` pertenece a un package.
- **module (go.mod)**: agrupa un proyecto Go y declara sus dependencias versionadas.
- **go.sum**: archivo autogenerado con los checksums criptográficos de cada dependencia,
  para garantizar que siempre se descargue exactamente el mismo código (seguridad e
  inmutabilidad).
- **struct**: tipo de dato compuesto, agrupa campos relacionados (similar a una clase sin
  métodos por defecto, o a un "objeto" simple).
- **pointer (`*Tipo`)**: una variable que guarda la dirección de memoria de otro valor, en
  lugar del valor mismo. Se usa para modificar el original o evitar copiar datos grandes.
- **`:=`**: operador de declaración corta de variables; declara e infiere el tipo al mismo
  tiempo (equivalente a `var x Tipo = valor` pero más conciso).
- **`context.Context`**: mecanismo estándar de Go para propagar cancelación, timeouts y
  valores a través de llamadas (especialmente útil en operaciones de red/DB).
- **`defer`**: pospone la ejecución de una instrucción hasta que la función actual termine
  (típicamente usado para liberar recursos, como cerrar una conexión).
- **`error`**: tipo estándar de Go para representar fallos; las funciones que pueden fallar
  retornan un `error` como último valor, y se revisa explícitamente con `if err != nil`.
- **`math/rand`**: paquete de la librería estándar para generar números pseudoaleatorios.

- **goroutine**: función que corre concurrentemente con el resto del programa, lanzada con
  la palabra `go` antes de la llamada (ej: `go runSimulator(ctx, pool)`). Más liviana que un
  hilo de sistema operativo tradicional.
- **struct tags** (`json:"campo"`): metadatos sobre un campo de struct, usados aquí por
  `encoding/json` (y por extensión Gin) para nombrar las claves al serializar a JSON.
- **slice** (`[]SensorData`): arreglo dinámico, puede crecer con `append`.
- **closure**: función anónima que "captura" variables del entorno donde fue definida
  (los handlers de Gin capturan `pool` sin recibirlo como parámetro explícito).
- **QueryRow vs Query**: `QueryRow` para 0 o 1 fila esperada; `Query` + `rows.Next()` +
  `rows.Scan()` + `rows.Close()` (con `defer`) para múltiples filas.

*(Este glosario se irá ampliando en cada sesión de trabajo.)*

### Endpoints REST disponibles (Paso 7)

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/status` | Última lectura registrada (404 si aún no hay datos) |
| GET | `/history?limit=N` | Últimas N lecturas, de más reciente a más antigua (default N=20) |

---

## 7. Flutter — Estado actual

**Aún no iniciado.** Se comenzará después de tener el backend simulando datos y
guardándolos correctamente en PostgreSQL. Conceptos pendientes de explicar cuando
lleguemos ahí: Widgets, MaterialApp, Scaffold, StatelessWidget, StatefulWidget,
BuildContext, Navigator, Column, Row, Container, Card, ListView, FutureBuilder.

---

## 8. Roadmap completo

- [x] Paso 1: Estructura de carpetas del proyecto
- [x] Paso 2: Inicializar módulo Go (`go mod init`)
- [x] Paso 3: Crear base de datos y tabla `sensor_data`
- [x] Paso 4: Backend — conectar a PostgreSQL con `pgxpool` y simular el PLC
- [x] Paso 5: Backend — función para leer el último registro (`getLatestReading`)
- [x] Paso 6: Backend — función para leer el historial (`getHistory`)
- [x] Paso 7: API REST con Gin (`/status`, `/history?limit=N`) + simulador en goroutine
- [x] Paso 8: Flutter — proyecto base (`main.dart`, `MaterialApp`)
- [x] Paso 9: Flutter — pantalla de estado actual + historial (`FutureBuilder`, `ListView`)
- [x] Paso 10: Flutter — gráfica de temperatura con `fl_chart`
- [x] Paso 11: Dockerizar backend + PostgreSQL (`Dockerfile` + `docker-compose.yml`)
      ← **estamos aquí**
- [ ] Paso 12: Autenticación con JWT (opcional para el portafolio, ver nota abajo)
- [ ] Paso 13: Pulido final: README de portafolio, capturas de pantalla, `.gitignore`

### Nota sobre el Paso 12 (JWT)
Para un proyecto de portafolio de monitoreo interno (una sola planta, sin multiusuario),
JWT es opcional: agrega complejidad sin aportar mucho valor demostrable a menos que el
entrevistador pregunte específicamente por autenticación. Recomendación: dejarlo como
"mejora futura" documentada en el README, y priorizar el Paso 13 (pulido y presentación)
para cerrar el proyecto pronto, tal como se pidió.

---

## 9. Cómo retomar el proyecto con otra IA

Si necesitas continuar este proyecto con otro asistente, comparte este documento completo
y dile:

> "Estoy desarrollando TankMonitor, un proyecto de portafolio con Go + PostgreSQL +
> Flutter. Aquí está la documentación completa del proyecto y las decisiones tomadas
> hasta ahora. Quiero continuar en el Paso [X del roadmap], manteniendo el mismo estilo:
> explicar conceptos antes de escribir código, comentar todo detalladamente porque estoy
> aprendiendo Go/Flutter desde cero, y seguir buenas prácticas (Clean Code, SOLID, KISS,
> DRY)."

---

## 10. Convenciones de código acordadas

- Comentarios en español, explicando el "por qué", no solo el "qué".
- Nombres de variables y funciones en inglés (convención estándar en Go/Flutter), pero
  explicaciones en español.
- Sin abreviaturas crípticas en nombres de variables.
- Cada función pública debe tener un comentario explicando su propósito (estilo Go doc).
