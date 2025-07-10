CREATE TABLE IF NOT EXISTS pagos (
    id SERIAL PRIMARY KEY,
    productos_cliente_id INTEGER NOT NULL,
    cliente_id INTEGER NOT NULL,
    fecha_pago DATE NOT NULL,
    valor NUMERIC(10,2) NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'COMPLETADO',
    saldo_pendiente NUMERIC(10,2) DEFAULT 0,
    saldo_a_favor NUMERIC(10,2) DEFAULT 0,
    referencia_pago VARCHAR(100),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

CREATE TABLE IF NOT EXISTS movimientos (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    descripcion TEXT,
    valor NUMERIC(10,2),
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    referencia VARCHAR(100)
    );

CREATE TABLE IF NOT EXISTS saldos_favor (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    valor_disponible NUMERIC(10,2) NOT NULL DEFAULT 0,
    valor_usado NUMERIC(10,2) NOT NULL DEFAULT 0,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_pagos_productos_cliente ON pagos(productos_cliente_id);
CREATE INDEX IF NOT EXISTS idx_pagos_cliente ON pagos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha_pago);
CREATE INDEX IF NOT EXISTS idx_movimientos_cliente ON movimientos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_saldos_favor_cliente ON saldos_favor(cliente_id);