-- =====================================================================
-- MIGRACION: AUSENCIAS (vacaciones, dias libres, permisos, incapacidades,
-- festivos) + REGLAS DE TURNOS DEL NEGOCIO.
-- Idempotente. Requiere haber ejecutado migracion_turnos_permisos.sql
-- (usa las funciones mi_tenant() y tiene_permiso()).
--
-- Como ejecutarla: Supabase Studio -> SQL Editor -> pegar -> Run
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. AUSENCIAS
--    user_id NULL = aplica a TODO el negocio (festivo, cierre).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ausencias (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id      uuid,
    tipo         text NOT NULL CHECK (tipo IN ('vacaciones', 'dia_libre', 'permiso', 'incapacidad', 'festivo')),
    fecha_inicio date NOT NULL,
    fecha_fin    date NOT NULL,
    notas        text,
    creado_por   uuid,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CHECK (fecha_fin >= fecha_inicio)
);

CREATE INDEX IF NOT EXISTS idx_ausencias_tenant_fechas ON public.ausencias(tenant_id, fecha_inicio, fecha_fin);
CREATE INDEX IF NOT EXISTS idx_ausencias_user          ON public.ausencias(user_id);

ALTER TABLE public.ausencias ENABLE ROW LEVEL SECURITY;

-- Cada quien ve las suyas y las del negocio entero; quien administra turnos ve todas.
DROP POLICY IF EXISTS "ausencias_select" ON public.ausencias;
CREATE POLICY "ausencias_select" ON public.ausencias
  FOR SELECT TO authenticated
  USING (tenant_id = public.mi_tenant()
         AND (user_id IS NULL
              OR user_id = auth.uid()
              OR public.tiene_permiso('turnos.administrar')));

DROP POLICY IF EXISTS "ausencias_write" ON public.ausencias;
CREATE POLICY "ausencias_write" ON public.ausencias
  FOR ALL TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'))
  WITH CHECK (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'));

-- ---------------------------------------------------------------------
-- 2. REGLAS DE TURNOS DEL NEGOCIO (una fila por empresa)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.turnos_config (
    tenant_id             uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
    tolerancia_retardo_min integer NOT NULL DEFAULT 10 CHECK (tolerancia_retardo_min >= 0),
    comida_minutos_default integer NOT NULL DEFAULT 30 CHECK (comida_minutos_default >= 0),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.turnos_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "turnos_config_select" ON public.turnos_config;
CREATE POLICY "turnos_config_select" ON public.turnos_config
  FOR SELECT TO authenticated USING (tenant_id = public.mi_tenant());

DROP POLICY IF EXISTS "turnos_config_write" ON public.turnos_config;
CREATE POLICY "turnos_config_write" ON public.turnos_config
  FOR ALL TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'))
  WITH CHECK (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'));

-- ---------------------------------------------------------------------
-- 3. Columnas de avatar en profiles (el calendario muestra la foto de cada quien)
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_style text,
  ADD COLUMN IF NOT EXISTS avatar_seed text,
  ADD COLUMN IF NOT EXISTS avatar_png text;

NOTIFY pgrst, 'reload schema';
