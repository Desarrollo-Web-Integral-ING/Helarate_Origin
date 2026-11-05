-- =====================================================================
-- MIGRACION: ROLES PERSONALIZADOS + CREACION DE USUARIOS EN SU EMPRESA
-- Idempotente. Requiere haber ejecutado antes migracion_turnos_permisos.sql
-- (usa mi_tenant(), mi_rol(), tiene_permiso(), permisos_default()).
--
-- Que hace:
--   1. roles_custom: el dueño crea roles (socio, reportes, supervisor...)
--      con los permisos que quiera.
--   2. tiene_permiso() entiende esos roles.
--   3. Solo quien puede administrar permisos puede cambiar el rol de alguien
--      (y nadie puede tocar al dueño ni cambiarse el rol a si mismo).
--   4. Las invitaciones solo se crean dentro de TU empresa.
--   5. Al activar su cuenta, la persona queda en la empresa y con el rol de
--      su invitacion (antes podia caer en la empresa por defecto).
--
-- Como ejecutarla: Supabase Studio -> SQL Editor -> pegar -> Run
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ROLES PERSONALIZADOS (uno por empresa)
--    profiles.rol guarda la "clave" del rol (p. ej. 'socio_a1b2').
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.roles_custom (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    clave       text NOT NULL,
    nombre      text NOT NULL,
    descripcion text,
    permisos    text[] NOT NULL DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, clave)
);

ALTER TABLE public.roles_custom ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "roles_custom_select" ON public.roles_custom;
CREATE POLICY "roles_custom_select" ON public.roles_custom
  FOR SELECT TO authenticated USING (tenant_id = public.mi_tenant());

DROP POLICY IF EXISTS "roles_custom_write" ON public.roles_custom;
CREATE POLICY "roles_custom_write" ON public.roles_custom
  FOR ALL TO authenticated
  USING (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar'))
  WITH CHECK (tenant_id = public.mi_tenant() AND public.tiene_permiso('permisos.administrar'));

-- ---------------------------------------------------------------------
-- 2. tiene_permiso(): ahora tambien resuelve roles personalizados
--    Prioridad: dueño/superadmin -> excepcion por usuario ->
--               rol personalizado -> excepcion por rol base -> valores por defecto
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tiene_permiso(p text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rol     text;
  v_tenant  uuid;
  v_val     boolean;
  v_perms   text[];
BEGIN
  SELECT rol, tenant_id INTO v_rol, v_tenant FROM public.profiles WHERE id = auth.uid();
  IF v_rol IS NULL THEN RETURN false; END IF;

  IF v_rol IN ('superadmin', 'dueño', 'dueno') THEN RETURN true; END IF;

  SELECT concedido INTO v_val FROM public.usuario_permisos
   WHERE user_id = auth.uid() AND permiso = p;
  IF FOUND THEN RETURN v_val; END IF;

  SELECT permisos INTO v_perms FROM public.roles_custom
   WHERE tenant_id = v_tenant AND clave = v_rol;
  IF FOUND THEN RETURN p = ANY (v_perms); END IF;

  SELECT concedido INTO v_val FROM public.rol_permisos
   WHERE tenant_id = v_tenant AND rol = v_rol AND permiso = p;
  IF FOUND THEN RETURN v_val; END IF;

  RETURN p = ANY (public.permisos_default(v_rol));
END;
$$;

GRANT EXECUTE ON FUNCTION public.tiene_permiso(text) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. PROTEGER EL CAMBIO DE ROL
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.proteger_cambio_rol()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rol_actor    text;
  v_tenant_actor uuid;
BEGIN
  IF NEW.rol IS NOT DISTINCT FROM OLD.rol THEN RETURN NEW; END IF;

  -- Sin sesion (SQL Editor, service role, triggers del sistema): se permite.
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;

  SELECT rol, tenant_id INTO v_rol_actor, v_tenant_actor FROM public.profiles WHERE id = auth.uid();
  IF v_rol_actor = 'superadmin' THEN RETURN NEW; END IF;

  IF OLD.id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes cambiar tu propio rol.';
  END IF;
  IF OLD.tenant_id IS DISTINCT FROM v_tenant_actor THEN
    RAISE EXCEPTION 'Ese usuario pertenece a otra empresa.';
  END IF;
  IF NOT public.tiene_permiso('permisos.administrar') THEN
    RAISE EXCEPTION 'No tienes permiso para cambiar roles.';
  END IF;
  IF OLD.rol IN ('dueño', 'dueno', 'superadmin') OR NEW.rol IN ('dueño', 'dueno', 'superadmin') THEN
    RAISE EXCEPTION 'El rol de dueño no se puede asignar ni quitar desde la app.';
  END IF;
  IF NEW.rol NOT IN ('admin', 'empleado')
     AND NOT EXISTS (SELECT 1 FROM public.roles_custom WHERE tenant_id = OLD.tenant_id AND clave = NEW.rol) THEN
    RAISE EXCEPTION 'Ese rol no existe en tu empresa.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_cambio_rol ON public.profiles;
CREATE TRIGGER trg_proteger_cambio_rol
  BEFORE UPDATE OF rol ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.proteger_cambio_rol();

-- ---------------------------------------------------------------------
-- 4. INVITACIONES SOLO DENTRO DE TU EMPRESA
--    - Con 'usuarios.administrar' puedes invitar empleados.
--    - Invitar con cualquier otro rol exige 'permisos.administrar'.
--    - El superadmin puede invitar a cualquier empresa (alta de duenos).
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.invitaciones') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "perm_invitaciones_insert" ON public.invitaciones';
    EXECUTE 'CREATE POLICY "perm_invitaciones_insert" ON public.invitaciones AS RESTRICTIVE
             FOR INSERT TO authenticated WITH CHECK (
               public.mi_rol() = ''superadmin''
               OR (tenant_id = public.mi_tenant()
                   AND public.tiene_permiso(''usuarios.administrar'')
                   AND (rol = ''empleado'' OR public.tiene_permiso(''permisos.administrar''))))';
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- 5. ALTA DE USUARIOS: la persona queda en la empresa de su invitacion
--    y con el rol que se le asigno. Si no hay invitacion, queda como
--    empleado de la empresa por defecto (nunca como dueño).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  inv        record;
  v_tenant   uuid;
  v_rol      text;
  v_nombre   text;
BEGIN
  SELECT * INTO inv FROM public.invitaciones
   WHERE lower(email) = lower(NEW.email)
   ORDER BY created_at DESC LIMIT 1;

  IF FOUND THEN
    v_tenant := inv.tenant_id;
    v_rol    := COALESCE(NULLIF(inv.rol, ''), 'empleado');
    v_nombre := COALESCE(NULLIF(inv.nombre, ''), split_part(NEW.email, '@', 1));
  ELSE
    SELECT id INTO v_tenant FROM public.tenants WHERE slug = 'helarate' LIMIT 1;
    v_rol    := COALESCE(NEW.raw_user_meta_data->>'rol', 'empleado');
    IF v_rol IN ('dueño', 'dueno', 'superadmin') THEN v_rol := 'empleado'; END IF;
    v_nombre := COALESCE(NEW.raw_user_meta_data->>'nombre',
                         NEW.raw_user_meta_data->>'full_name',
                         split_part(NEW.email, '@', 1));
  END IF;

  INSERT INTO public.profiles (id, email, nombre, nombre_completo, rol, tenant_id, avatar_style, avatar_seed)
  VALUES (NEW.id, NEW.email, v_nombre, v_nombre, v_rol, v_tenant, 'gradiente', NEW.id::text)
  ON CONFLICT (id) DO UPDATE SET
    tenant_id = COALESCE(public.profiles.tenant_id, EXCLUDED.tenant_id),
    rol       = CASE WHEN public.profiles.rol IS NULL THEN EXCLUDED.rol ELSE public.profiles.rol END,
    nombre    = COALESCE(public.profiles.nombre, EXCLUDED.nombre);

  -- La invitacion ya se uso: deja de aparecer como pendiente.
  IF inv.id IS NOT NULL THEN
    DELETE FROM public.invitaciones WHERE id = inv.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

NOTIFY pgrst, 'reload schema';
