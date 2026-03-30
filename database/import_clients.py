#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════╗
║       IMPORTADOR DE CLIENTES                                 ║
║                                                              ║
║  Lee el Excel, limpia y valida cada campo. Si hay errores    ║
║  que no pueden corregirse automáticamente, se detiene y      ║
║  reporta los problemas. Si todo está bien, genera el .sql    ║
╚══════════════════════════════════════════════════════════════╝

Uso:
    python importar_clientes.py

Salida:
    clientes_insert.sql  → listo para revisar y ejecutar en PostgreSQL
"""

import pandas as pd
import re
import sys
from datetime import datetime

# ================================================================
# CONFIGURACIÓN ─ ajusta según tu base de datos
# ================================================================
EXCEL_FILE         = ""
OUTPUT_SQL         = "clientes_insert.sql"
SECCIONAL_ID = 0      # ID de la seccional 'CAUCA' en tu tabla seccional

# ================================================================
# CONSTANTES DE VALIDACIÓN
# ================================================================
ESTADOS_VALIDOS = {
    "PENSIONADO", "INHABILITADO", "ACTIVO",
    "VIGENTE", "CANCELADO", "SALIO_DE_LA_RAMA",
}

# Mapeo de variantes textuales → valor del CHECK constraint
MAPA_ESTADOS = {
    "VIGENTE":            "VIGENTE",
    "ACTIVO":             "ACTIVO",
    "ACTIVE":             "ACTIVO",
    "CANCELADO":          "CANCELADO",
    "PENSIONADO":         "PENSIONADO",
    "INHABILITADO":       "INHABILITADO",
    "SALIO DE LA RAMA":   "SALIO_DE_LA_RAMA",
    "SALIO_DE_LA_RAMA":   "SALIO_DE_LA_RAMA",
    "SALIO DE LA RAMA ":  "SALIO_DE_LA_RAMA",
}

# Primeros nombres típicos colombianos para detectar formato NOMBRES-APELLIDOS
NOMBRES_TIPICOS = {
    "JORGE", "DANIEL", "MARIA", "JUAN", "ANA", "LUIS", "CARLOS",
    "PEDRO", "MIGUEL", "JOSE", "LAURA", "DIANA", "ANDRES", "ALEJANDRO",
    "SANDRA", "CLAUDIA", "MONICA", "PATRICIA", "ADRIANA", "CAMILO",
}

# ================================================================
# FUNCIONES DE LIMPIEZA
# ================================================================

def limpiar_texto(valor) -> str | None:
    """Strip + mayúsculas. Retorna None si está vacío."""
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return None
    limpio = str(valor).strip().upper()
    return limpio if limpio else None


def limpiar_cedula(valor) -> str | None:
    """
    Elimina espacios, puntos, guiones, comas.
    Convierte float → int (ej: 76308963.0 → '76308963').
    """
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return None
    # Quitar .0 de floats antes de procesar
    texto = re.sub(r'\.0+$', '', str(valor).strip())
    solo_digitos = re.sub(r'[\s.\-,]', '', texto)
    return solo_digitos if solo_digitos else None


def limpiar_celular(valor) -> str | None:
    """
    • Si hay múltiples números (separados por ';' o ','), toma el primero.
    • Elimina espacios, guiones, paréntesis y deja solo dígitos.
    """
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return None
    texto = str(valor).strip()
    primero = re.split(r'[;,]', texto)[0].strip()
    solo_digitos = re.sub(r'[^\d]', '', primero)
    return solo_digitos if solo_digitos else None


def limpiar_telefono(valor) -> str | None:
    """
    • Elimina extensiones: 'Ext 551', 'ext. 23', '#123'.
    • Deja solo los dígitos del número principal.
    """
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return None
    texto = str(valor).strip()
    # Remover extensiones antes de extraer dígitos
    texto = re.sub(r'\b[Ee]xt\.?\s*\d+', '', texto)
    texto = re.sub(r'#\d+', '', texto)
    solo_digitos = re.sub(r'[^\d]', '', texto)
    return solo_digitos if solo_digitos else None


def limpiar_correo(valor) -> str | None:
    """
    • Si hay múltiples correos (separados por ';' o ','), toma el primero.
    • Strip + lowercase.
    """
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return None
    texto = str(valor).strip()
    primero = re.split(r'[;,]', texto)[0].strip()
    return primero.lower() if primero else None


def limpiar_estado(valor) -> str | None:
    """Normaliza al valor exacto del CHECK constraint."""
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return "ACTIVO"  # valor por defecto de la tabla
    limpio = str(valor).strip().upper()
    return MAPA_ESTADOS.get(limpio, limpio)


def split_nombre(nombre_completo: str, formato: str = "apellidos_primero") -> tuple[str, str]:
    """
    Divide un nombre completo en (apellidos, nombres).

    formato='apellidos_primero' → APELLIDO1 APELLIDO2 NOMBRE1 NOMBRE2
    formato='nombres_primero'   → NOMBRE1 NOMBRE2 APELLIDO1 APELLIDO2

    Regla: siempre se reservan las primeras 2 palabras para el grupo
    principal (apellidos o nombres según el formato), el resto va al otro.
    Si solo hay 2 palabras, se asigna 1 a cada grupo.
    """
    partes = nombre_completo.strip().split()
    if len(partes) == 0:
        return ("", "")
    if len(partes) == 1:
        return (partes[0], "")
    if len(partes) == 2:
        if formato == "apellidos_primero":
            return (partes[0], partes[1])
        else:
            return (partes[1], partes[0])
    # 3+ palabras
    if formato == "apellidos_primero":
        apellidos = " ".join(partes[:2])
        nombres   = " ".join(partes[2:])
    else:
        nombres   = " ".join(partes[:2])
        apellidos = " ".join(partes[2:])
    return (apellidos, nombres)


def detectar_formato_nombre(nombre: str) -> str:
    """
    Heurística: si la primera palabra es un nombre típico colombiano
    (JORGE, DANIEL, MARIA…) asume formato 'nombres_primero';
    de lo contrario, 'apellidos_primero'.
    """
    if not nombre:
        return "apellidos_primero"
    primera = nombre.strip().split()[0].upper()
    return "nombres_primero" if primera in NOMBRES_TIPICOS else "apellidos_primero"


# ================================================================
# FUNCIONES DE VALIDACIÓN
# ================================================================

def validar_cedula(cedula: str | None, campo: str, fila: int) -> list[str]:
    errores = []
    if not cedula:
        errores.append(f"Fila {fila} [{campo}]: cédula vacía o nula")
        return errores
    if not re.match(r'^\d{4,12}$', cedula):
        errores.append(
            f"Fila {fila} [{campo}]: '{cedula}' no es válida "
            f"(solo dígitos, entre 4 y 12 caracteres)"
        )
    return errores


def validar_celular(celular: str | None, fila: int) -> list[str]:
    errores = []
    if not celular:
        errores.append(f"Fila {fila} [CELULAR]: vacío o nulo")
        return errores
    if not re.match(r'^3\d{9}$', celular):
        errores.append(
            f"Fila {fila} [CELULAR]: '{celular}' no es válido "
            f"(debe tener exactamente 10 dígitos y comenzar con 3)"
        )
    return errores


def validar_telefono(telefono: str | None, campo: str, fila: int) -> list[str]:
    """Teléfono fijo es opcional; si existe, debe tener 7 u 8 dígitos."""
    errores = []
    if not telefono:
        return errores
    if not re.match(r'^\d{7,8}$', telefono):
        errores.append(
            f"Fila {fila} [{campo}]: '{telefono}' no es válido "
            f"(debe tener 7 u 8 dígitos numéricos)"
        )
    return errores


def validar_correo(correo: str | None, fila: int) -> list[str]:
    errores = []
    if not correo:
        return errores
    patron = r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'
    if not re.match(patron, correo):
        errores.append(
            f"Fila {fila} [E-MAIL]: '{correo}' no tiene formato de correo válido"
        )
    return errores


def validar_estado(estado: str | None, fila: int) -> list[str]:
    errores = []
    if not estado:
        return errores
    if estado not in ESTADOS_VALIDOS:
        errores.append(
            f"Fila {fila} [ESTADO]: '{estado}' no está permitido. "
            f"Valores válidos: {sorted(ESTADOS_VALIDOS)}"
        )
    return errores


def validar_nombres(apellidos: str, nombres: str, campo: str, fila: int) -> list[str]:
    errores = []
    if not apellidos or not apellidos.strip():
        errores.append(f"Fila {fila} [{campo} - apellidos]: vacíos tras el split")
    if not nombres or not nombres.strip():
        errores.append(f"Fila {fila} [{campo} - nombres]: vacíos tras el split")
    return errores


# ================================================================
# HELPERS SQL
# ================================================================

def sql_str(valor) -> str:
    """Convierte un valor Python a literal SQL (con comillas o NULL)."""
    if valor is None or valor == "" or (isinstance(valor, float) and pd.isna(valor)):
        return "NULL"
    escaped = str(valor).replace("'", "''")
    return f"'{escaped}'"


def sql_date(valor) -> str:
    """Convierte una fecha a literal SQL DATE o NULL."""
    if valor is None or (isinstance(valor, float) and pd.isna(valor)):
        return "NULL"
    try:
        ts = pd.Timestamp(valor)
        return f"'{ts.strftime('%Y-%m-%d')}'"
    except Exception:
        return "NULL"


# ================================================================
# PROGRAMA PRINCIPAL
# ================================================================

def main():
    SEP = "─" * 62

    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║       IMPORTADOR DE CLIENTES — DIRECTORIO CAUCA             ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()

    # ── Leer Excel ──────────────────────────────────────────────────
    try:
        df = pd.read_excel(EXCEL_FILE, header=1)
    except FileNotFoundError:
        print(f"❌ No se encontró el archivo: {EXCEL_FILE}")
        sys.exit(1)
    except Exception as exc:
        print(f"❌ Error al leer el Excel: {exc}")
        sys.exit(1)

    print(f"✔ Archivo leído correctamente → {len(df)} registros\n")
    print(SEP)

    todos_errores   = []   # errores que detienen el script
    advertencias    = []   # avisos informativos (no detienen)
    registros_ok    = []   # filas procesadas sin error

    for idx, row in df.iterrows():
        fila = idx + 3  # fila real en el Excel (header ocupa fila 2)

        # ── Limpiar ─────────────────────────────────────────────────
        nombre_emp_raw  = limpiar_texto(row.get("APELLIDOS Y NOMBRES"))
        nombre_otro_raw = limpiar_texto(
            row.get("APELLIDOS Y NOMBRES (OTRO ASEGURADO DIFERENTE AL EMPLEADO )")
        )
        cedula_emp      = limpiar_cedula(row.get("CEDULA EMPLEADO"))
        cedula_otro_raw = limpiar_cedula(row.get("CEDULA ASEGURADO"))
        fecha_nac       = row.get("FECHA DE NACIMIENTO")
        dir_res         = limpiar_texto(row.get("DIRECCION RESIDENCIA"))
        tel_res         = limpiar_telefono(row.get("TEL. RES"))
        dir_ofi         = limpiar_texto(row.get("DIR. OFICINA"))
        tel_ofi_raw     = str(row.get("TEL. OFICINA", "")).strip()
        tel_ofi         = limpiar_telefono(row.get("TEL. OFICINA"))
        correo_raw      = str(row.get("E-MAIL", "")).strip()
        correo          = limpiar_correo(row.get("E-MAIL"))
        celular_raw     = str(row.get("CELULAR", "")).strip()
        celular         = limpiar_celular(row.get("CELULAR"))
        estado_raw      = str(row.get("ESTADO ", "")).strip()
        estado          = limpiar_estado(row.get("ESTADO "))

        # ── Informar auto-correcciones ───────────────────────────────
        if ";" in celular_raw or "," in celular_raw:
            advertencias.append(
                f"  Fila {fila} [CELULAR]: múltiples números '{celular_raw}' "
                f"→ se usará el primero: '{celular}'"
            )
        if ";" in correo_raw or "," in correo_raw:
            advertencias.append(
                f"  Fila {fila} [E-MAIL]: múltiples correos '{correo_raw}' "
                f"→ se usará el primero: '{correo}'"
            )
        if "ext" in tel_ofi_raw.lower() and tel_ofi:
            advertencias.append(
                f"  Fila {fila} [TEL. OFICINA]: extensión eliminada "
                f"'{tel_ofi_raw}' → '{tel_ofi}'"
            )
        if estado_raw != estado and estado_raw:
            advertencias.append(
                f"  Fila {fila} [ESTADO]: normalizado '{estado_raw}' → '{estado}'"
            )

        # ── Split de nombres ─────────────────────────────────────────
        if nombre_emp_raw:
            apellidos_emp, nombres_emp = split_nombre(nombre_emp_raw, "apellidos_primero")
        else:
            apellidos_emp, nombres_emp = "", ""

        # Para el otro asegurado detectamos el formato automáticamente
        apellidos_otro, nombres_otro = "", ""
        formato_otro = "apellidos_primero"
        if nombre_otro_raw:
            formato_otro = detectar_formato_nombre(nombre_otro_raw)
            apellidos_otro, nombres_otro = split_nombre(nombre_otro_raw, formato_otro)
            if formato_otro == "nombres_primero":
                advertencias.append(
                    f"  Fila {fila} [OTRO ASEGURADO]: nombre '{nombre_otro_raw}' "
                    f"detectado como formato NOMBRES-APELLIDOS → "
                    f"apellidos='{apellidos_otro}', nombres='{nombres_otro}' — verifica manualmente"
                )

        # ¿Hay otro asegurado real (cédula diferente al empleado)?
        cedula_otro = None
        tiene_otro  = False
        if nombre_otro_raw and cedula_otro_raw and cedula_otro_raw != cedula_emp:
            cedula_otro = cedula_otro_raw
            tiene_otro  = True

        # ── Validar ──────────────────────────────────────────────────
        errores_fila = []

        errores_fila += validar_cedula(cedula_emp, "CEDULA EMPLEADO", fila)
        errores_fila += validar_nombres(apellidos_emp, nombres_emp, "EMPLEADO", fila)
        errores_fila += validar_celular(celular, fila)
        errores_fila += validar_telefono(tel_res, "TEL. RES", fila)
        errores_fila += validar_telefono(tel_ofi, "TEL. OFICINA", fila)
        errores_fila += validar_correo(correo, fila)
        errores_fila += validar_estado(estado, fila)

        if tiene_otro:
            errores_fila += validar_cedula(cedula_otro, "CEDULA ASEGURADO", fila)
            errores_fila += validar_nombres(apellidos_otro, nombres_otro, "OTRO ASEGURADO", fila)

        if errores_fila:
            todos_errores.extend(errores_fila)
        else:
            registros_ok.append({
                "fila":           fila,
                "cedula_emp":     cedula_emp,
                "apellidos_emp":  apellidos_emp,
                "nombres_emp":    nombres_emp,
                "fecha_nac":      fecha_nac,
                "dir_res":        dir_res,
                "tel_res":        tel_res,
                "dir_ofi":        dir_ofi,
                "tel_ofi":        tel_ofi,
                "correo":         correo,
                "celular":        celular,
                "estado":         estado,
                "tiene_otro":     tiene_otro,
                "cedula_otro":    cedula_otro,
                "apellidos_otro": apellidos_otro,
                "nombres_otro":   nombres_otro,
            })

    # ── Resumen de advertencias ──────────────────────────────────────
    if advertencias:
        print("⚠  AUTO-CORRECCIONES APLICADAS:")
        for a in advertencias:
            print(a)
        print(SEP)

    # ── Detener si hay errores ───────────────────────────────────────
    if todos_errores:
        print(f"\n❌  ENCONTRADOS {len(todos_errores)} ERROR(ES) — No se generó el archivo SQL\n")
        print(SEP)
        for e in todos_errores:
            print(f"  • {e}")
        print(SEP)
        print()
        print("  Corrige los errores en el Excel y vuelve a ejecutar el script.")
        print()
        sys.exit(1)

    # ── Generar SQL ──────────────────────────────────────────────────
    print(f"\n✔ Todos los registros son válidos ({len(registros_ok)} filas)")
    print(f"  Generando {OUTPUT_SQL}...\n")

    lineas = []
    lineas += [
        "-- ============================================================",
        f"-- Importación: DIRECTORIO CAUCA",
        f"-- Generado:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"-- Registros:   {len(registros_ok)} clientes",
        "-- ============================================================",
        "-- IMPORTANTE: Revisa el archivo antes de ejecutarlo.",
        "-- Verifica que SECCIONAL_ID corresponda al valor correcto en",
        "-- tu tabla `seccional`.",
        "-- ============================================================",
        "",
        "BEGIN;",
        "",
    ]

    for r in registros_ok:
        lineas.append(
            f"-- [{r['fila']}] {r['apellidos_emp']} {r['nombres_emp']} "
            f"| CC {r['cedula_emp']}"
        )

        # ── INSERT cliente (empleado) ────────────────────────────────
        lineas += [
            "INSERT INTO clientes (",
            "    nombres, apellidos, cedula,",
            "    fecha_nacimiento, direccion_residencia,",
            "    telefono_residencia, direccion_oficina, telefono_oficina,",
            "    correo, celular, seccional_id, estado",
            ")",
            "VALUES (",
            f"    {sql_str(r['nombres_emp'])}, {sql_str(r['apellidos_emp'])}, {sql_str(r['cedula_emp'])},",
            f"    {sql_date(r['fecha_nac'])}, {sql_str(r['dir_res'])},",
            f"    {sql_str(r['tel_res'])}, {sql_str(r['dir_ofi'])}, {sql_str(r['tel_ofi'])},",
            f"    {sql_str(r['correo'])}, {sql_str(r['celular'])}, {SECCIONAL_ID}, {sql_str(r['estado'])}",
            ") ON CONFLICT (cedula) DO NOTHING;",
            "",
        ]

        # ── INSERT asegurado (empleado) ──────────────────────────────
        lineas += [
            "INSERT INTO asegurados (cliente_id, tipo_asegurado)",
            f"    SELECT id, 'CLIENTE' FROM clientes WHERE cedula = {sql_str(r['cedula_emp'])};",
            "",
        ]

        # ── Otro asegurado (si existe y cédula diferente) ────────────
        if r["tiene_otro"]:
            lineas.append(
                f"-- Otro asegurado: {r['apellidos_otro']} {r['nombres_otro']} "
                f"| CC {r['cedula_otro']}"
            )
            lineas += [
                "INSERT INTO clientes (",
                "    nombres, apellidos, cedula, seccional_id, estado",
                ")",
                "VALUES (",
                f"    {sql_str(r['nombres_otro'])}, {sql_str(r['apellidos_otro'])}, "
                f"{sql_str(r['cedula_otro'])}, {SECCIONAL_ID}, 'VIGENTE'",
                ") ON CONFLICT (cedula) DO NOTHING;",
                "",
                "INSERT INTO asegurados (cliente_id, tipo_asegurado)",
                f"    SELECT id, 'BENEFICIARIO' FROM clientes WHERE cedula = {sql_str(r['cedula_otro'])};",
                "",
            ]

        lineas.append("")  # línea en blanco entre registros

    lineas += [
        "COMMIT;",
        "",
        "-- ── Verificación post-inserción ────────────────────────────",
        "SELECT COUNT(*) AS clientes_insertados    FROM clientes;",
        "SELECT COUNT(*) AS asegurados_insertados  FROM asegurados;",
    ]

    with open(OUTPUT_SQL, "w", encoding="utf-8") as f:
        f.write("\n".join(lineas))

    # ── Resumen final ────────────────────────────────────────────────
    otros_count = sum(1 for r in registros_ok if r["tiene_otro"])
    print(SEP)
    print(f"  ✔ {OUTPUT_SQL} generado exitosamente")
    print(f"  • {len(registros_ok)} clientes (empleados)")
    print(f"  • {otros_count} beneficiarios adicionales")
    print(f"  • {len(registros_ok) + otros_count} filas en total en 'asegurados'")
    print(SEP)
    print()
    print("  Pasos siguientes:")
    print(f"  1. Abre {OUTPUT_SQL} y verifica que los nombres estén bien divididos.")
    print(f"  2. Confirma que seccional_id = {SECCIONAL_ID} es correcto para CAUCA.")
    print("  3. Ejecuta en PostgreSQL:  \\i clientes_insert.sql")
    print()


if __name__ == "__main__":
    main()