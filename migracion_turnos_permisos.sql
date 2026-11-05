-- =====================================================================
-- MIGRACION: TURNOS (entrada / salida / comida / horarios) + PERMISOS
-- Idempotente: se puede ejecutar varias veces.
--
-- Como ejecutarla:
--   Supabase Studio -> SQL Editor -> pegar todo -> Run
--   (local: http://127.0.0.1:54323)
--
-- Requiere que ya existan las tablas tenants y profiles
-- (ejecuta antes migracion_alinear_esquema_app.sql si falta algo).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. FUNCIONES AUXILIARES
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mi_tenant()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT tenant_id FROM public.profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT rol FROM public.profiles WHERE id = auth.uid()
$$;

-- ---------------------------------------------------------------------
-- 2. PERMISOS
--    Catalogo (debe coincidir con lib/core/permissions/permiso.dart):
--      dashboard.ver
--      insumos.ver, insumos.editar
--      catalogo.ver, catalogo.editar
--      ventas.ver, ventas.historial, ventas.eliminar
--      estadisticas.ver
--      usuarios.ver, usuarios.administrar
--      personalizacion.ver
--      equipos.configurar
--      turnos.propios, turnos.administrar
--      permisos.administrar
--
--    Orden de prioridad al evaluar un permiso:
--      1) superadmin y dueno: siempre concedido
--      2) excepcion por USUARIO (usuario_permisos)
--      3) excepcion por ROL de la empresa (rol_permisos)
--      4) valores por defecto del rol (permisos_default)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rol_permisos (
    tenant_id  uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    rol        text NOT NULL,
    permiso    text NOT NULL,
    concedido  boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, rol, permiso)
);

CREATE TABLE IF NOT EXISTS public.usuario_permisos (
    user_id    uuid NOT NULL,
    tenant_id  uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    permiso    text NOT NULL,
    concedido  boolean NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, permiso)
);

CREATE INDEX IF NOT EXISTS idx_usuario_permisos_tenant ON public.usuario_permisos(tenant_id);

CREATE OR REPLACE FUNCTION public.permisos_default(p_rol text)
RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_rol IN ('superadmin', 'dueño', 'dueno') THEN ARRAY[
      'dashboard.ver','insumos.ver','insumos.editar','catalogo.ver','catalogo.editar',
      'ventas.ver','ventas.historial','ventas.eliminar','estadisticas.ver',
      'usuarios.ver','usuarios.administrar','personalizacion.ver','equipos.configurar',
      'turnos.propios','turnos.administrar','permisos.administrar']
    WHEN p_rol = 'admin' THEN ARRAY[
      'dashboard.ver','insumos.ver','insumos.editar','catalogo.ver','catalogo.editar',
      'ventas.ver','ventas.historial','ventas.eliminar','estadisticas.ver',
      'usuarios.ver','usuarios.administrar','personalizacion.ver','equipos.configurar',
      'turnos.propios','turnos.administrar']
    ELSE ARRAY[
      'dashboard.ver','insumos.ver','catalogo.ver','ventas.ver','ventas.historial',
      'equipos.configurar','turnos.propios']
  END
$$;

CREATE OR REPLACE FUNCTION public.tiene_permiso(p text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rol    text;
  v_tenant uuid;
  v_val    boolean;
BEGIN
  SELECT rol, tenant_id INTO v_rol, v_tenant FROM public.profiles WHERE id = auth.uid();
  IF v_rol IS NULL THEN RETURN false; END IF;

  -- El superadmin y el dueño nunca pierden permisos (evita quedarse sin acceso).
  IF v_rol IN ('superadmin', 'dueño', 'dueno') THEN RETURN true; END IF;

  SELECT concedido INTO v_val FROM public.usuario_permisos
   WHERE user_id = auth.uid() AND permiso = p;
  IF FOUND THEN RETURN v_val; END IF;

  SELECT concedido INTO v_val FROM public.rol_permisos
   WHERE tenant_id = v_tenant AND rol = v_rol AND permiso = p;
  IF FOUND THEN RETURN v_val; END IF;

  RETURN p = ANY (public.permisos_default(v_rol));
END;
$$;

GRANT EXECUTE ON FUNCTION public.mi_tenant()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.mi_rol()             TO authenticated;
GRANT EXECUTE ON FUNCTION public.permisos_default(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tiene_permiso(text)  TO authenticated;

ALTER TABLE public.rol_permisos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_permisos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rol_permisos_select" ON public.rol_permisos;
CREATE POLICY "rol_permisos_select" ON public.rol_permisos
  FOR SELECT TO authenticated USING (tenant_id = public.mi_tenant());

DROP POLICY IF EXISTS "rol_permisos_write" ON public.rol_permisos;
CREATE POLICY "rol_permisos_write" ON public.rol_permisos
  FOR ALL TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar'))
  WITH CHECK (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar'));

DROP POLICY IF EXISTS "usuario_permisos_select" ON public.usuario_permisos;
CREATE POLICY "usuario_permisos_select" ON public.usuario_permisos
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()
         OR (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar')));

DROP POLICY IF EXISTS "usuario_permisos_write" ON public.usuario_permisos;
CREATE POLICY "usuario_permisos_write" ON public.usuario_permisos
  FOR ALL TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar'))
  WITH CHECK (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar'));

-- ---------------------------------------------------------------------
-- 3. TURNOS: HORARIOS Y ASISTENCIAS
-- ---------------------------------------------------------------------
-- Horario semanal de cada empleado (dia_semana ISO: 1 = lunes ... 7 = domingo)
CREATE TABLE IF NOT EXISTS public.horarios_empleado (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id        uuid NOT NULL,
    dia_semana     smallint NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    hora_entrada   time NOT NULL,
    hora_salida    time NOT NULL,
    comida_minutos integer NOT NULL DEFAULT 30 CHECK (comida_minutos >= 0),
    activo         boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, dia_semana)
);

-- Registro real: entrada, comida y salida
CREATE TABLE IF NOT EXISTS public.asistencias (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id          uuid NOT NULL,
    fecha            date NOT NULL DEFAULT CURRENT_DATE,
    entrada          timestamptz,
    comida_inicio    timestamptz,
    comida_fin       timestamptz,
    salida           timestamptz,
    retardo_minutos  integer NOT NULL DEFAULT 0,
    notas            text,
    editado_por      uuid,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_asistencias_tenant_fecha ON public.asistencias(tenant_id, fecha);
CREATE INDEX IF NOT EXISTS idx_asistencias_user_fecha   ON public.asistencias(user_id, fecha);
CREATE INDEX IF NOT EXISTS idx_horarios_tenant          ON public.horarios_empleado(tenant_id);

-- Un empleado no puede tener dos turnos abiertos a la vez
CREATE UNIQUE INDEX IF NOT EXISTS ux_asistencia_abierta
  ON public.asistencias(user_id) WHERE salida IS NULL;

ALTER TABLE public.horarios_empleado ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencias       ENABLE ROW LEVEL SECURITY;

-- Horarios: cada quien ve el suyo; quien administra turnos ve y edita todos
DROP POLICY IF EXISTS "horarios_select" ON public.horarios_empleado;
CREATE POLICY "horarios_select" ON public.horarios_empleado
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()
         OR (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar')));

DROP POLICY IF EXISTS "horarios_write" ON public.horarios_empleado;
CREATE POLICY "horarios_write" ON public.horarios_empleado
  FOR ALL TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'))
  WITH CHECK (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'));

-- Asistencias: cada quien registra y ve las suyas; el administrador, todas
DROP POLICY IF EXISTS "asistencias_select" ON public.asistencias;
CREATE POLICY "asistencias_select" ON public.asistencias
  FOR SELECT TO authenticated
  USING (user_id = auth.uid()
         OR (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar')));

DROP POLICY IF EXISTS "asistencias_insert" ON public.asistencias;
CREATE POLICY "asistencias_insert" ON public.asistencias
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = public.mi_tenant()
              AND ((user_id = auth.uid() AND public.tiene_permiso('turnos.propios'))
                   OR public.tiene_permiso('turnos.administrar')));

DROP POLICY IF EXISTS "asistencias_update" ON public.asistencias;
CREATE POLICY "asistencias_update" ON public.asistencias
  FOR UPDATE TO authenticated
  USING (tenant_id = public.mi_tenant()
         AND ((user_id = auth.uid() AND public.tiene_permiso('turnos.propios'))
              OR public.tiene_permiso('turnos.administrar')))
  WITH CHECK (tenant_id = public.mi_tenant());

DROP POLICY IF EXISTS "asistencias_delete" ON public.asistencias;
CREATE POLICY "asistencias_delete" ON public.asistencias
  FOR DELETE TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('turnos.administrar'));

-- ---------------------------------------------------------------------
-- 4. APLICAR PERMISOS EN TABLAS EXISTENTES (politicas RESTRICTIVAS)
--    Se suman (AND) a las politicas que ya tengas: no reemplazan nada.
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.ventas') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "perm_ventas_insert" ON public.ventas';
    EXECUTE 'CREATE POLICY "perm_ventas_insert" ON public.ventas AS RESTRICTIVE
             FOR INSERT TO authenticated WITH CHECK (public.tiene_permiso(''ventas.ver''))';

    EXECUTE 'DROP POLICY IF EXISTS "perm_ventas_delete" ON public.ventas';
    EXECUTE 'CREATE POLICY "perm_ventas_delete" ON public.ventas AS RESTRICTIVE
             FOR DELETE TO authenticated USING (public.tiene_permiso(''ventas.eliminar''))';
  END IF;

  IF to_regclass('public.insumos') IS NOT NULL THEN
    -- Crear / borrar productos exige el permiso de editar segun el tipo.
    -- (Actualizar NO se restringe porque cada venta descuenta stock.)
    EXECUTE 'DROP POLICY IF EXISTS "perm_insumos_insert" ON public.insumos';
    EXECUTE 'CREATE POLICY "perm_insumos_insert" ON public.insumos AS RESTRICTIVE
             FOR INSERT TO authenticated WITH CHECK (
               (tipo::text = ''Materia Prima'' AND public.tiene_permiso(''insumos.editar''))
               OR (tipo::text <> ''Materia Prima'' AND public.tiene_permiso(''catalogo.editar'')))';

    EXECUTE 'DROP POLICY IF EXISTS "perm_insumos_delete" ON public.insumos';
    EXECUTE 'CREATE POLICY "perm_insumos_delete" ON public.insumos AS RESTRICTIVE
             FOR DELETE TO authenticated USING (
               (tipo::text = ''Materia Prima'' AND public.tiene_permiso(''insumos.editar''))
               OR (tipo::text <> ''Materia Prima'' AND public.tiene_permiso(''catalogo.editar'')))';
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- 5. Refrescar la cache de esquema de PostgREST
-- ---------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
