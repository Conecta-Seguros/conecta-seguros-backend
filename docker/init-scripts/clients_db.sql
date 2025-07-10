CREATE TABLE IF NOT EXISTS aseguradora (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    nit VARCHAR(20) UNIQUE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'
    );

CREATE TABLE IF NOT EXISTS seccional (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    vigencia_inicio DATE NOT NULL,
    vigencia_fin DATE NOT NULL,
    departamento VARCHAR(50) NOT NULL,
    aseguradora_id INTEGER NOT NULL REFERENCES aseguradora(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'
    );

CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) UNIQUE NOT NULL,
    direccion_residencia VARCHAR(200),
    municipio VARCHAR(100),
    telefono_residencia VARCHAR(20),
    direccion_oficina VARCHAR(200),
    telefono_oficina VARCHAR(20),
    correo VARCHAR(150),
    celular VARCHAR(20),
    seccional_id INTEGER REFERENCES seccional(id),
    sede VARCHAR(100),
    juzgado VARCHAR(100),
    cargo VARCHAR(100),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE IF NOT EXISTS asegurados (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) NOT NULL,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_clientes_cedula ON clientes(cedula);
CREATE INDEX IF NOT EXISTS idx_clientes_seccional ON clientes(seccional_id);
CREATE INDEX IF NOT EXISTS idx_asegurados_cliente ON asegurados(cliente_id);
CREATE INDEX IF NOT EXISTS idx_asegurados_cedula ON asegurados(cedula);