CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tipo VARCHAR(50),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'
    );

CREATE TABLE IF NOT EXISTS polizas (
    id SERIAL PRIMARY KEY,
    numero VARCHAR(50) UNIQUE NOT NULL,
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    aseguradora_id INTEGER NOT NULL,
    vigencia_inicio DATE NOT NULL,
    vigencia_fin DATE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO'
    );

CREATE TABLE IF NOT EXISTS productos_cliente (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    poliza_id INTEGER NOT NULL REFERENCES polizas(id),
    asegurado_id INTEGER NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    valor_anual NUMERIC(12,2) NOT NULL,
    valor_cuota_mensual NUMERIC(10,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_cancelacion TIMESTAMP
    );

CREATE TABLE IF NOT EXISTS vehiculos (
    id SERIAL PRIMARY KEY,
    placa VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    color VARCHAR(30),
    asegurado_id INTEGER NOT NULL,
    productos_cliente_id INTEGER REFERENCES productos_cliente(id),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_polizas_numero ON polizas(numero);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_cliente ON productos_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_poliza ON productos_cliente(poliza_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_placa ON vehiculos(placa);