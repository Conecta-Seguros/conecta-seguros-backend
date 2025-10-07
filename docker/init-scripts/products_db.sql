CREATE TABLE IF NOT EXISTS planes_producto (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(10) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    cobertura_monto NUMERIC(14,2),
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT chk_planes_estado CHECK (estado IN ('ACTIVO','INACTIVO')),
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
    aseguradora_nit VARCHAR(20) NOT NULL,
    cliente_cedula VARCHAR(20) NOT NULL,
    vigencia_inicio DATE NOT NULL,
    vigencia_fin DATE NOT NULL,
    valor_total_anual NUMERIC(12,2) NOT NULL CHECK (valor_total_anual >= 0),
    valor_primera_cuota NUMERIC(12,2),
    tiene_cuota_prorrateada BOOLEAN DEFAULT FALSE,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_creacion UUID,
    usuario_modificacion UUID,
    CONSTRAINT chk_polizas_fechas CHECK (vigencia_inicio <= vigencia_fin),
    CONSTRAINT chk_polizas_estado CHECK (estado IN ('ACTIVO','CANCELADA','VENCIDA','SUSPENDIDA'))
    );

CREATE TABLE IF NOT EXISTS productos_cliente (
    id SERIAL PRIMARY KEY,
    poliza_id INTEGER NOT NULL REFERENCES polizas(id) ON DELETE CASCADE,
    asegurado_cedula VARCHAR(20) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_cancelacion TIMESTAMP,
    motivo_cancelacion TEXT,
    usuario_creacion INTEGER,
    usuario_modificacion INTEGER,
    CONSTRAINT chk_pc_estado CHECK (estado IN ('ACTIVO','CANCELADO','VIGENTE','PENDIENTE','SUSPENDIDO')),
    UNIQUE (poliza_id, asegurado_cedula)
    );

CREATE TABLE IF NOT EXISTS vehiculos (
    id SERIAL PRIMARY KEY,
    placa VARCHAR(10) UNIQUE NOT NULL,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    asegurado_cedula VARCHAR(20) NOT NULL,
    productos_cliente_id INTEGER REFERENCES productos_cliente(id) ON DELETE CASCADE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_planes_tipo_nombre ON planes_producto(tipo, nombre);

CREATE INDEX IF NOT EXISTS idx_productos_tipo ON productos(tipo);
CREATE INDEX IF NOT EXISTS idx_productos_plan ON productos(plan_id);

CREATE INDEX IF NOT EXISTS idx_polizas_numero ON polizas(numero);
CREATE INDEX IF NOT EXISTS idx_polizas_aseguradora_nit ON polizas(aseguradora_nit);
CREATE INDEX IF NOT EXISTS idx_polizas_cliente_cedula ON polizas(cliente_cedula);
CREATE INDEX IF NOT EXISTS idx_polizas_vigencias ON polizas(vigencia_fin, vigencia_inicio);
CREATE INDEX IF NOT EXISTS idx_polizas_cuota_prorrateada ON polizas(tiene_cuota_prorrateada);

CREATE INDEX IF NOT EXISTS idx_productos_cliente_poliza ON productos_cliente(poliza_id);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_asegurado_cedula ON productos_cliente(asegurado_cedula);
CREATE INDEX IF NOT EXISTS idx_productos_cliente_estado ON productos_cliente(estado);

CREATE INDEX IF NOT EXISTS idx_vehiculos_placa ON vehiculos(placa);
CREATE INDEX IF NOT EXISTS idx_vehiculos_asegurado_cedula ON vehiculos(asegurado_cedula);
CREATE INDEX IF NOT EXISTS idx_vehiculos_prod_cliente ON vehiculos(productos_cliente_id);

CREATE INDEX IF NOT EXISTS idx_detalle_cuotas_poliza ON detalle_cuotas(poliza_id);
CREATE INDEX IF NOT EXISTS idx_detalle_cuotas_estado ON detalle_cuotas(estado);