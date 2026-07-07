# ---------------------------------------------------------------------
# STAGE 1: "builder" — compila el binario de Go
# ---------------------------------------------------------------------
# Usamos una imagen que ya trae el compilador de Go instalado. La
# etiqueta "AS builder" le pone nombre a esta etapa para poder
# referenciarla después.
FROM golang:1.22-alpine AS builder

# Directorio de trabajo dentro del contenedor. Todo lo que hagamos desde
# aquí (COPY, RUN, etc.) es relativo a esta carpeta.
WORKDIR /app

# Copiamos PRIMERO solo los archivos de dependencias (go.mod, go.sum).
# Esto es una optimización de cache de Docker: mientras no cambien las
# dependencias, Docker reutiliza esta capa y NO vuelve a descargar todo
# en cada build, aunque cambiemos el código fuente después.
COPY go.mod go.sum ./
RUN go mod download

# Ahora sí copiamos el resto del código fuente.
COPY . .

# Compilamos el binario. CGO_ENABLED=0 desactiva dependencias de
# librerías C del sistema operativo, produciendo un binario 100%
# autocontenido (necesario para que corra en la imagen "alpine" final,
# que es mínima y no trae esas librerías).
RUN CGO_ENABLED=0 GOOS=linux go build -o tankmonitor-backend .

# ---------------------------------------------------------------------
# STAGE 2: imagen final — solo el binario compilado, sin el compilador
# ---------------------------------------------------------------------
# "alpine" es una distribución de Linux extremadamente liviana (~5MB).
# No necesitamos el compilador de Go aquí, solo un sistema mínimo para
# correr el binario ya compilado. Esto hace la imagen final mucho más
# pequeña que si usáramos la imagen de "builder" para todo.
FROM alpine:3.19

WORKDIR /app

# Copiamos ÚNICAMENTE el binario compilado desde la etapa "builder".
# Esta es la magia del "multi-stage build": el resultado final no
# incluye el código fuente ni las herramientas de compilación.
COPY --from=builder /app/tankmonitor-backend .

# Puerto que expone el servidor Gin (definido en main.go: router.Run(":8080"))
EXPOSE 8080

# Comando que se ejecuta cuando arranca el contenedor.
CMD ["./tankmonitor-backend"]
