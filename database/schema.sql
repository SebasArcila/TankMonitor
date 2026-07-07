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