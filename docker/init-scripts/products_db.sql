CREATE TABLE IF NOT EXISTS planes_producto (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    cobertura_monto NUMERIC(14,2),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT chk_planes_tipo CHECK (tipo IN ('SALUD','VIDA','OTRO')),
    CONSTRAINT chk_planes_nombre_por_tipo CHECK (
    (tipo = 'SALUD' AND nombre IN ('EVOLUCIONA','GLOBAL','CLASICO','SALUD_PARA_TODOS'))
    OR (tipo = 'VIDA' AND nombre IN ('PLAN_A','PLAN_B','PLAN_C'))
    OR (tipo = 'OTRO')
    ),
    CONSTRAINT chk_planes_cobertura_por_tipo CHECK ((tipo = 'VIDA' AND cobertura_monto IS NOT NULL AND cobertura_monto > 0)
    OR (tipo = 'SALUD' AND cobertura_monto IS NULL)),
    CONSTRAINT chk_planes_estado CHECK (estado IN ('ACTIVO','INACTIVO','DESCONTINUADO')),
    UNIQUE (tipo, nombre)
    );

CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tipo VARCHAR(50),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    plan_id INTEGER REFERENCES planes_producto(id),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_productos_tipo CHECK (tipo IN ('SALUD','VIDA','VEHICULAR','OTRO')),
    CONSTRAINT chk_productos_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
    );

CREATE TABLE IF NOT EXISTS polizas (
    id SERIAL PRIMARY KEY,
    numero VARCHAR(50) UNIQUE NOT NULL,
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    aseguradora_id INTEGER NOT NULL,
    vigencia_inicio DATE NOT NULL,
    vigencia_fin DATE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT chk_polizas_fechas CHECK (vigencia_inicio <= vigencia_fin),
    CONSTRAINT chk_polizas_estado CHECK (estado IN ('ACTIVO','CANCELADA','VENCIDA','SUSPENDIDA'))
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
    fecha_cancelacion TIMESTAMP,
    CONSTRAINT chk_pc_valores CHECK (valor_anual >= 0 AND valor_cuota_mensual >= 0),
    CONSTRAINT chk_pc_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT chk_pc_estado CHECK (estado IN ('ACTIVO','CANCELADO','VIGENTE','PENDIENTE','SUSPENDIDO'))
    );

CREATE TABLE IF NOT EXISTS vehiculos (
    id SERIAL PRIMARY KEY,
    placa VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    asegurado_id INTEGER NOT NULL,
    productos_cliente_id INTEGER REFERENCES productos_cliente(id),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_planes_tipo_nombre ON planes_producto(tipo, nombre);
CREATE INDEX IF NOT EXISTS idx_productos_tipo ON productos(tipo);
CREATE INDEX IF NOT EXISTS idx_productos_plan ON productos(plan_id);
CREATE INDEX IF NOT EXISTS idx_polizas_numero ON polizas(numero);
CREATE INDEX IF NOT EXISTS idx_polizas_aseguradora ON polizas(aseguradora_id);
CREATE INDEX IF NOT EXISTS idx_polizas_vigencias ON polizas(vigencia_fin, vigencia_inicio);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_cliente ON productos_cliente(cliente_id);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_poliza ON productos_cliente(poliza_id);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_asegurado ON productos_cliente(asegurado_id);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_estado ON productos_cliente(estado);
CREATE INDEX IF NOT EXISTS idx_vehiculos_placa ON vehiculos(placa);
CREATE INDEX IF NOT EXISTS idx_vehiculos_asegurado ON vehiculos(asegurado_id);
CREATE INDEX IF NOT EXISTS idx_vehiculos_prod_cliente ON vehiculos(productos_cliente_id);