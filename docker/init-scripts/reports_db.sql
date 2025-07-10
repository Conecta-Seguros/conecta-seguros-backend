CREATE TABLE IF NOT EXISTS reportes_generados (
    id SERIAL PRIMARY KEY,
    nombre_reporte VARCHAR(100) NOT NULL,
    tipo_reporte VARCHAR(50) NOT NULL,
    parametros TEXT,
    ruta_archivo VARCHAR(500),
    usuario_generacion INTEGER NOT NULL,
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'GENERADO'
    );

CREATE TABLE IF NOT EXISTS notificaciones (
    id SERIAL PRIMARY KEY,
    destinatario_id INTEGER NOT NULL,
    tipo_destinatario VARCHAR(20) NOT NULL,
    tipo_notificacion VARCHAR(50) NOT NULL,
    asunto VARCHAR(200),
    mensaje TEXT NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_envio TIMESTAMP,
    intentos INTEGER DEFAULT 0
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_reportes_usuario ON reportes_generados(usuario_generacion);
CREATE INDEX IF NOT EXISTS idx_reportes_fecha ON reportes_generados(fecha_generacion);
CREATE INDEX IF NOT EXISTS idx_notificaciones_destinatario ON notificaciones(destinatario_id);
CREATE INDEX IF NOT EXISTS idx_notificaciones_estado ON notificaciones(estado);