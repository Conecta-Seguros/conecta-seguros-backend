CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) UNIQUE NOT NULL,
    correo VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(50) NOT NULL, -- 'CLIENTE', 'ADMINISTRADOR', 'EMPLEADO'
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP,
    token_recuperacion VARCHAR(255),
    token_expiracion TIMESTAMP
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_cedula ON users(cedula);
CREATE INDEX IF NOT EXISTS idx_users_correo ON users(correo);
CREATE INDEX IF NOT EXISTS idx_users_rol ON users(rol);