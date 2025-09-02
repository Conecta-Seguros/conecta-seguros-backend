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
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    UNIQUE (nombre)
    );

CREATE TABLE IF NOT EXISTS departamento (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    seccional_id INTEGER NOT NULL REFERENCES seccional(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    UNIQUE (seccional_id, nombre)
    );

CREATE TABLE IF NOT EXISTS municipio (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    departamento_id INTEGER NOT NULL REFERENCES departamento(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    UNIQUE (departamento_id, nombre)
    );

CREATE TABLE IF NOT EXISTS sede (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    municipio_id INTEGER NOT NULL REFERENCES municipio(id),
    seccional_id INTEGER NOT NULL REFERENCES seccional(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    UNIQUE (municipio_id, nombre)
    );

CREATE TABLE IF NOT EXISTS juzgado (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    sede_id INTEGER NOT NULL REFERENCES sede(id),
    municipio_id INTEGER NOT NULL REFERENCES municipio(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    UNIQUE (sede_id, nombre)
    );

CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) UNIQUE NOT NULL,
    fecha_nacimiento DATE,
    direccion_residencia VARCHAR(200),
    departamento_id INTEGER REFERENCES departamento(id),
    municipio_id INTEGER REFERENCES municipio(id),
    telefono_residencia VARCHAR(20),
    direccion_oficina VARCHAR(200),
    telefono_oficina VARCHAR(20),
    correo VARCHAR(150) UNIQUE,
    celular VARCHAR(20),
    seccional_id INTEGER REFERENCES seccional(id),
    sede_id INTEGER REFERENCES sede(id),
    juzgado_id INTEGER REFERENCES juzgado(id),
    cargo VARCHAR(100),
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_clientes_estado CHECK (estado IN ('PENSIONADO','INHABILITADO','ACTIVO','VIGENTE','CANCELADO','SALIO_DE_LA_RAMA'))
    );

CREATE TABLE IF NOT EXISTS asegurados (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    tipo_asegurado VARCHAR(20) NOT NULL CHECK (tipo_asegurado IN ('CLIENTE', 'TERCERO')),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE IF NOT EXISTS asegurado_tercero_detalle (
    asegurado_id INTEGER PRIMARY KEY REFERENCES asegurados(id) ON DELETE CASCADE,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    cedula VARCHAR(20) NOT NULL
    );

CREATE TABLE IF NOT EXISTS cliente_seccional_historial (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    seccional_anterior_id INTEGER REFERENCES seccional(id),
    seccional_nueva_id INTEGER NOT NULL REFERENCES seccional(id),
    fecha_cambio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notificado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_notificacion TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_departamento_seccional ON departamento(seccional_id);
CREATE INDEX IF NOT EXISTS idx_municipio_departamento ON municipio(departamento_id);
CREATE INDEX IF NOT EXISTS idx_sede_municipio ON sede(municipio_id);
CREATE INDEX IF NOT EXISTS idx_sede_seccional ON sede(seccional_id);
CREATE INDEX IF NOT EXISTS idx_juzgado_sede ON juzgado(sede_id);
CREATE INDEX IF NOT EXISTS idx_juzgado_municipio ON juzgado(municipio_id);

CREATE INDEX IF NOT EXISTS idx_clientes_cedula ON clientes(cedula);
CREATE INDEX IF NOT EXISTS idx_clientes_seccional ON clientes(seccional_id);
CREATE INDEX IF NOT EXISTS idx_clientes_departamento ON clientes(departamento_id);
CREATE INDEX IF NOT EXISTS idx_clientes_municipio ON clientes(municipio_id);
CREATE INDEX IF NOT EXISTS idx_clientes_sede ON clientes(sede_id);
CREATE INDEX IF NOT EXISTS idx_clientes_juzgado ON clientes(juzgado_id);
CREATE INDEX IF NOT EXISTS idx_clientes_correo ON clientes(correo);
CREATE INDEX IF NOT EXISTS idx_clientes_estado ON clientes(estado);
CREATE INDEX IF NOT EXISTS idx_clientes_seccional_estado ON clientes(seccional_id, estado);

CREATE INDEX IF NOT EXISTS idx_asegurados_cliente_id ON asegurados(cliente_id);
CREATE INDEX IF NOT EXISTS idx_asegurados_tipo ON asegurados(tipo_asegurado);
CREATE UNIQUE INDEX IF NOT EXISTS idx_unq_asegurado_cliente_self ON asegurados(cliente_id) WHERE tipo_asegurado = 'CLIENTE';
CREATE INDEX IF NOT EXISTS idx_asegurados_cliente_tipo ON asegurados(cliente_id, tipo_asegurado);
CREATE INDEX IF NOT EXISTS idx_tercero_cedula ON asegurado_tercero_detalle(cedula);
