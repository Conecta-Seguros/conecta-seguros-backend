CREATE TABLE IF NOT EXISTS novedades (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    aseguradora_id INTEGER NOT NULL,
    seccional_id INTEGER NOT NULL,
    cedula_cliente VARCHAR(20),
    descripcion TEXT,
    cuota NUMERIC(10,2) NOT NULL,
    valor NUMERIC(10,2) NOT NULL,
    nomina VARCHAR(100),
    fecha DATE NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    archivo_id INTEGER,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_nov_valores CHECK (cuota >= 0 AND valor >= 0),
    CONSTRAINT chk_nov_estado CHECK (estado IN ('PENDIENTE','PROCESANDO','PROCESADO','CONCILIADO','RECHAZADO','ERROR'))
    );

CREATE TABLE IF NOT EXISTS descuentos (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    seccional_id INTEGER NOT NULL,
    aseguradora_id INTEGER,
    cedula_cliente VARCHAR(20) NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    fecha DATE NOT NULL,
    codigo_descuento VARCHAR(50) NOT NULL,
    codigo_validacion VARCHAR(50),
    valor NUMERIC(10,2) NOT NULL,
    valor_esperado NUMERIC(10,2),
    diferencia NUMERIC(10,2) DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    archivo_id INTEGER,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_desc_valores CHECK (valor >= 0 AND (valor_esperado IS NULL OR valor_esperado >= 0)),
    CONSTRAINT chk_desc_estado CHECK (estado IN ('PENDIENTE','PROCESANDO','PROCESADO','CONCILIADO','EXCEDENTE','FALTANTE','NO_LLEGO','ERROR')),
    CONSTRAINT chk_desc_diferencia CHECK (diferencia = (valor - COALESCE(valor_esperado, 0)))
    );

CREATE TABLE IF NOT EXISTS archivos_novedades (
    id SERIAL PRIMARY KEY,
    nombre_archivo VARCHAR(255) NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    seccional_id INTEGER NOT NULL,
    total_registros INTEGER NOT NULL DEFAULT 0,
    registros_exitosos INTEGER NOT NULL DEFAULT 0,
    registros_errores INTEGER NOT NULL DEFAULT 0,
    excedentes INTEGER NOT NULL DEFAULT 0,
    faltantes INTEGER NOT NULL DEFAULT 0,
    no_llegaron INTEGER NOT NULL DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'PROCESANDO',
    ruta_archivo VARCHAR(500),
    contenido BYTEA,
    checksum_sha256 VARCHAR(64),
    tamano_bytes BIGINT,
    tipo_mime VARCHAR(100),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga INTEGER NOT NULL,
    CONSTRAINT chk_arch_nov_estado CHECK (estado IN ('PROCESANDO','PROCESADO','ERROR'))
    );

CREATE TABLE IF NOT EXISTS archivos_descuentos (
    id SERIAL PRIMARY KEY,
    nombre_archivo VARCHAR(255) NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    seccional_id INTEGER NOT NULL,
    total_registros INTEGER NOT NULL DEFAULT 0,
    registros_procesados INTEGER NOT NULL DEFAULT 0,
    diferencias_encontradas INTEGER NOT NULL DEFAULT 0,
    excedentes INTEGER NOT NULL DEFAULT 0,
    faltantes INTEGER NOT NULL DEFAULT 0,
    no_llegaron INTEGER NOT NULL DEFAULT 0,
    estado VARCHAR(20) NOT NULL DEFAULT 'CARGADO',
    ruta_archivo VARCHAR(500),
    contenido BYTEA,
    checksum_sha256 VARCHAR(64),
    tamano_bytes BIGINT,
    tipo_mime VARCHAR(100),
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_carga INTEGER NOT NULL,
    CONSTRAINT chk_arch_desc_estado CHECK (estado IN ('CARGADO', 'PROCESANDO','PROCESADO','ERROR'))
    );

CREATE TABLE IF NOT EXISTS errores_procesamiento (
    id SERIAL PRIMARY KEY,
    archivo_id INTEGER NOT NULL,
    tipo_archivo VARCHAR(20) NOT NULL,
    linea_archivo INTEGER,
    cedula_cliente VARCHAR(20),
    periodo VARCHAR(7),
    seccional_id INTEGER,
    tipo_error VARCHAR(50) NOT NULL,
    descripcion_error TEXT,
    contenido_linea TEXT,
    fecha_error TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_err_tipo_archivo CHECK (tipo_archivo IN ('NOVEDADES','DESCUENTOS'))
    );

CREATE TABLE IF NOT EXISTS conciliaciones (
    id SERIAL PRIMARY KEY,
    periodo VARCHAR(7) NOT NULL,
    seccional_id INTEGER NOT NULL,
    aseguradora_id INTEGER,
    cliente_id INTEGER,
    cedula_cliente VARCHAR(20),
    novedad_id INTEGER REFERENCES novedades(id) ON DELETE SET NULL,
    descuento_id INTEGER REFERENCES descuentos(id) ON DELETE SET NULL,
    codigo_descuento VARCHAR(50),
    valor_esperado NUMERIC(10,2),
    valor_descuento NUMERIC(10,2),
    diferencia NUMERIC(10,2) NOT NULL,
    estado VARCHAR(20) NOT NULL,
    fecha_conciliacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observaciones TEXT,
    CONSTRAINT chk_conc_estado CHECK (estado IN ('CONCILIADO','PENDIENTE','EXCEDENTE','FALTANTE','NO_LLEGO','ERROR')),
    CONSTRAINT chk_conc_diff CHECK (diferencia = (COALESCE(valor_descuento,0) - COALESCE(valor_esperado,0)))
    );

CREATE TABLE IF NOT EXISTS archivos_compilados (
    id SERIAL PRIMARY KEY,
    tipo_compilado VARCHAR(30) NOT NULL,
    periodo VARCHAR(7) NOT NULL,
    seccional_id INTEGER NOT NULL,
    nombre_archivo VARCHAR(255) NOT NULL,
    ruta_archivo VARCHAR(500),
    contenido BYTEA,
    checksum_sha256 VARCHAR(64),
    tamano_bytes BIGINT,
    total_registros INTEGER DEFAULT 0,
    generado_por INTEGER,
    fecha_generado TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

ALTER TABLE novedades
    ADD CONSTRAINT fk_novedades_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos_novedades(id) ON DELETE SET NULL;

ALTER TABLE descuentos
    ADD CONSTRAINT fk_descuentos_archivo
        FOREIGN KEY (archivo_id) REFERENCES archivos_descuentos(id) ON DELETE SET NULL;

-- Índices
CREATE INDEX IF NOT EXISTS idx_novedades_cliente ON novedades(cliente_id);
CREATE INDEX IF NOT EXISTS idx_novedades_periodo ON novedades(periodo);
CREATE INDEX IF NOT EXISTS idx_novedades_seccional ON novedades(seccional_id);
CREATE INDEX IF NOT EXISTS idx_descuentos_cliente ON descuentos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_descuentos_periodo ON descuentos(fecha);
CREATE INDEX IF NOT EXISTS idx_descuentos_estado ON descuentos(estado);
CREATE INDEX IF NOT EXISTS idx_archivos_novedades_periodo ON archivos_novedades(periodo);
CREATE INDEX IF NOT EXISTS idx_archivos_descuentos_periodo ON archivos_descuentos(periodo);
CREATE INDEX IF NOT EXISTS idx_novedades_estado ON novedades(estado);
CREATE INDEX IF NOT EXISTS idx_novedades_aseguradora ON novedades(aseguradora_id);
CREATE INDEX IF NOT EXISTS idx_novedades_archivo ON novedades(archivo_id);

CREATE INDEX IF NOT EXISTS idx_descuentos_periodo ON descuentos(periodo);
CREATE INDEX IF NOT EXISTS idx_descuentos_seccional ON descuentos(seccional_id);
CREATE INDEX IF NOT EXISTS idx_descuentos_codigo ON descuentos(codigo_descuento);
CREATE UNIQUE INDEX IF NOT EXISTS idx_descuentos_unq ON descuentos(cliente_id, seccional_id, periodo, codigo_descuento, archivo_id);

CREATE INDEX IF NOT EXISTS idx_arch_nov_periodo ON archivos_novedades(periodo);
CREATE INDEX IF NOT EXISTS idx_arch_nov_estado ON archivos_novedades(estado);
CREATE INDEX IF NOT EXISTS idx_arch_desc_periodo ON archivos_descuentos(periodo);
CREATE INDEX IF NOT EXISTS idx_arch_desc_estado ON archivos_descuentos(estado);

CREATE INDEX IF NOT EXISTS idx_errores_periodo ON errores_procesamiento(periodo);
CREATE INDEX IF NOT EXISTS idx_errores_seccional ON errores_procesamiento(seccional_id);
CREATE INDEX IF NOT EXISTS idx_errores_tipo_archivo ON errores_procesamiento(tipo_archivo);

CREATE INDEX IF NOT EXISTS idx_conciliaciones_periodo ON conciliaciones(periodo);
CREATE INDEX IF NOT EXISTS idx_conciliaciones_estado ON conciliaciones(estado);
CREATE INDEX IF NOT EXISTS idx_conciliaciones_seccional ON conciliaciones(seccional_id);
CREATE INDEX IF NOT EXISTS idx_conciliaciones_cliente ON conciliaciones(cliente_id);