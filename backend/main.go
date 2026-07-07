package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SensorData representa la lectura de los sensores de un tanque.
type SensorData struct {
	ID          int       `json:"id"`
	Temperature float64   `json:"temperature"`
	PH          float64   `json:"ph"`
	Level       float64   `json:"level"`
	Pump        bool      `json:"pump"`
	CreatedAt   time.Time `json:"created_at"`
}

// generateSensorData genera datos aleatorios pero realistas para simular un sensor industrial.
func generateSensorData() SensorData {
	temperature := 15.0 + rand.Float64()*(30.0-15.0)
	ph := 6.0 + rand.Float64()*(8.5-6.0)
	level := rand.Float64() * 100.0
	pump := rand.Intn(2) == 1

	return SensorData{
		Temperature: temperature,
		PH:          ph,
		Level:       level,
		Pump:        pump,
	}
}

// insertSensorData almacena una lectura en la base de datos PostgreSQL.
func insertSensorData(ctx context.Context, pool *pgxpool.Pool, data SensorData) error {
	_, err := pool.Exec(ctx,
		`INSERT INTO sensor_data (temperature, ph, level, pump)
		 VALUES ($1, $2, $3, $4)`,
		data.Temperature, data.PH, data.Level, data.Pump,
	)
	return err
}

// getLatestReading retorna la lectura de sensor más reciente.
func getLatestReading(ctx context.Context, pool *pgxpool.Pool) (SensorData, error) {
	var data SensorData

	row := pool.QueryRow(ctx,
		`SELECT id, temperature, ph, level, pump, created_at
		 FROM sensor_data
		 ORDER BY created_at DESC
		 LIMIT 1`,
	)

	err := row.Scan(&data.ID, &data.Temperature, &data.PH, &data.Level, &data.Pump, &data.CreatedAt)
	if err != nil {
		return SensorData{}, err
	}

	return data, nil
}

// getHistory obtiene las últimas N lecturas registradas.
func getHistory(ctx context.Context, pool *pgxpool.Pool, limit int) ([]SensorData, error) {
	rows, err := pool.Query(ctx,
		`SELECT id, temperature, ph, level, pump, created_at
		 FROM sensor_data
		 ORDER BY created_at DESC
		 LIMIT $1`,
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	results := []SensorData{}
	for rows.Next() {
		var data SensorData
		if err := rows.Scan(&data.ID, &data.Temperature, &data.PH, &data.Level, &data.Pump, &data.CreatedAt); err != nil {
			return nil, err
		}
		results = append(results, data)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return results, nil
}

// runSimulator ejecuta el bucle de simulación del PLC, insertando datos cada segundo.
func runSimulator(ctx context.Context, pool *pgxpool.Pool) {
	fmt.Println("🚀 Simulador de PLC iniciado. Generando datos cada segundo...")

	for {
		data := generateSensorData()

		if err := insertSensorData(ctx, pool, data); err != nil {
			log.Printf("⚠️ Error insertando lectura: %v", err)
		} else {
			log.Printf("📊 Lectura guardada -> temp: %.2f°C | pH: %.2f | nivel: %.2f%% | bomba: %t",
				data.Temperature, data.PH, data.Level, data.Pump)
		}

		time.Sleep(time.Second)
	}
}

// setupRouter configura el servidor web Gin y sus endpoints.
func setupRouter(pool *pgxpool.Pool) *gin.Engine {
	router := gin.Default()

	// Configuración de CORS
	router.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		MaxAge:           12 * time.Hour,
	}))

	// GET /status -> última lectura del tanque
	router.GET("/status", func(c *gin.Context) {
		data, err := getLatestReading(c.Request.Context(), pool)
		if err != nil {
			if err == pgx.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "todavía no hay lecturas registradas"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "error interno del servidor"})
			return
		}
		c.JSON(http.StatusOK, data)
	})

	// GET /history?limit=N -> historial de lecturas (por defecto 20)
	router.GET("/history", func(c *gin.Context) {
		limit := 20
		if raw := c.Query("limit"); raw != "" {
			parsed, err := strconv.Atoi(raw)
			if err == nil && parsed > 0 {
				limit = parsed
			}
		}

		results, err := getHistory(c.Request.Context(), pool, limit)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "error interno del servidor"})
			return
		}
		c.JSON(http.StatusOK, results)
	})

	return router
}

func main() {
	ctx := context.Background()

	// Intentar obtener la URL de base de datos desde la variable de entorno,
	// o usar un valor local por defecto sin credenciales comprometidas.
	connString := os.Getenv("DATABASE_URL")
	if connString == "" {
		connString = "postgres://postgres:postgres@localhost:5432/tankmonitor?sslmode=disable"
	}

	pool, err := pgxpool.New(ctx, connString)
	if err != nil {
		log.Fatalf("no se pudo crear el pool de conexiones: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("no se pudo conectar a PostgreSQL: %v", err)
	}
	fmt.Println("✅ Conectado a PostgreSQL correctamente.")

	// Lanzar simulador en segundo plano
	go runSimulator(ctx, pool)

	router := setupRouter(pool)

	fmt.Println("🌐 Servidor HTTP escuchando en http://localhost:8080")
	fmt.Println("   Endpoints: GET /status   GET /history?limit=20")

	if err := router.Run(":8080"); err != nil {
		log.Fatalf("error iniciando el servidor HTTP: %v", err)
	}
}
