CREATE TABLE IF NOT EXISTS novedades (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    aseguradora_id INTEGER NOT NULL,
    seccional_id INTEGER NOT NULL,
    descripcion TEXT,
    cuota NUMERIC(10,2) NOT NULL,
    valor NUMERIC(10,2) NOT NULL,
    nomina VARCHAR(100),
    fecha DATE NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    archivo_id INTEGER,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE IF NOT EXISTS descuentos (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    seccional_id INTEGER NOT NULL,
    fecha DATE NOT NULL,
    valor NUMERIC(10,2) NOT NULL,
    valor_esperado NUMERIC(10,2),
    diferencia NUMERIC(10,2) DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    archivo_id INTEGER,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE IF NOT EXISTS archivos_novedades (
    id SERIAL PRIMARY KEY,
    nombre_archivo VARCHAR(255) NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    seccional_id INTEGER NOT NULL,
    total_registros INTEGER NOT NULL DEFAULT 0,
    registros_exitosos INTEGER NOT NULL DEFAULT 0,
    registros_errores INTEGER NOT NULL DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'PROCESANDO',
    ruta_archivo VARCHAR(500),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga INTEGER NOT NULL
    );

CREATE TABLE IF NOT EXISTS archivos_descuentos (
    id SERIAL PRIMARY KEY,
    nombre_archivo VARCHAR(255) NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    seccional_id INTEGER NOT NULL,
    total_registros INTEGER NOT NULL DEFAULT 0,
    registros_procesados INTEGER NOT NULL DEFAULT 0,
    diferencias_encontradas INTEGER NOT NULL DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'PROCESANDO',
    ruta_archivo VARCHAR(500),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga INTEGER NOT NULL
    );

CREATE TABLE IF NOT EXISTS errores_procesamiento (
    id SERIAL PRIMARY KEY,
    archivo_id INTEGER NOT NULL,
    tipo_archivo VARCHAR(20) NOT NULL,
    linea_archivo INTEGER,
    cedula_cliente VARCHAR(20),
    tipo_error VARCHAR(50) NOT NULL,
    descripcion_error TEXT,
    fecha_error TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_novedades_cliente ON novedades(cliente_id);
CREATE INDEX IF NOT EXISTS idx_novedades_periodo ON novedades(periodo);
CREATE INDEX IF NOT EXISTS idx_novedades_seccional ON novedades(seccional_id);
CREATE INDEX IF NOT EXISTS idx_descuentos_cliente ON descuentos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_descuentos_periodo ON descuentos(fecha);
CREATE INDEX IF NOT EXISTS idx_descuentos_estado ON descuentos(estado);
CREATE INDEX IF NOT EXISTS idx_archivos_novedades_periodo ON archivos_novedades(periodo);
CREATE INDEX IF NOT EXISTS idx_archivos_descuentos_periodo ON archivos_descuentos(periodo);