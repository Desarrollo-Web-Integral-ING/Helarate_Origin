-- =====================================================================
-- MIGRACION: alinea la base de datos con lo que la app realmente usa.
-- Es idempotente (se puede ejecutar varias veces) y solo AGREGA cosas.
--
-- Corrige el error:
--   PostgrestException: Could not find the 'total_costos' column of
--   'ventas' in the schema cache (PGRST204)
--
-- Como ejecutarla (entorno local / Docker):
--   Supabase Studio -> SQL Editor (http://127.0.0.1:54323) -> pegar -> Run
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. VENTAS: columnas que envia la app
-- ---------------------------------------------------------------------
ALTER TABLE public.ventas
  ADD COLUMN IF NOT EXISTS total_ingresos numeric(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_costos   numeric(12, 2) NOT NULL DEFAULT 0;

-- ganancia_neta se calcula sola (la app no la envia al insertar)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ventas'
      AND column_name = 'ganancia_neta'
  ) THEN
    ALTER TABLE public.ventas
      ADD COLUMN ganancia_neta numeric(12, 2)
      GENERATED ALWAYS AS (total_ingresos - total_costos) STORED;
  END IF;
END $$;

-- Si habia ventas guardadas con la columna antigua "total", conservarlas
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ventas'
      AND column_name = 'total'
  ) THEN
    UPDATE public.ventas SET total_ingresos = total
    WHERE total_ingresos = 0 AND total > 0;
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- 2. DETALLE_VENTA
-- ---------------------------------------------------------------------
ALTER TABLE public.detalle_venta
  ADD COLUMN IF NOT EXISTS precio_venta_unitario numeric(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS costo_unitario        numeric(12, 2) NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------
-- 3. PROFILES: la app usa "nombre" y guarda la aceptacion del aviso
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS nombre text,
  ADD COLUMN IF NOT EXISTS aceptado_aviso_at timestamptz,
  ADD COLUMN IF NOT EXISTS aviso_version text;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'nombre_completo'
  ) THEN
    UPDATE public.profiles SET nombre = nombre_completo WHERE nombre IS NULL;
  END IF;
END $$;

-- El trigger de alta de usuarios tambien debe llenar "nombre"
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_tenant_id UUID;
    display_name TEXT;
BEGIN
    SELECT id INTO default_tenant_id FROM public.tenants WHERE slug = 'helarate' LIMIT 1;
    display_name := COALESCE(
        NEW.raw_user_meta_data->>'nombre',
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1)
    );

    INSERT INTO public.profiles (id, email, nombre, nombre_completo, rol, tenant_id, avatar_style, avatar_seed)
    VALUES (
        NEW.id,
        NEW.email,
        display_name,
        display_name,
        COALESCE(NEW.raw_user_meta_data->>'rol', 'dueño'),
        default_tenant_id,
        'bottts',
        NEW.id::text
    )
    ON CONFLICT (id) DO UPDATE SET
        tenant_id = COALESCE(public.profiles.tenant_id, EXCLUDED.tenant_id),
        nombre = COALESCE(public.profiles.nombre, EXCLUDED.nombre);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------
-- 4. TENANTS: la app crea empresas sin "slug"
-- ---------------------------------------------------------------------
ALTER TABLE public.tenants ALTER COLUMN slug DROP NOT NULL;

-- ---------------------------------------------------------------------
-- 5. AUDIT_LOGS (bitacora que la app escribe en login/registro)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid,
    action text NOT NULL,
    table_name text NOT NULL,
    record_id uuid,
    descripcion text,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dev_audit_policy" ON public.audit_logs;
CREATE POLICY "dev_audit_policy" ON public.audit_logs
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 6. INVITACIONES (alta de duenos y empleados)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invitaciones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,
    nombre text,
    email text NOT NULL,
    rol text NOT NULL DEFAULT 'empleado',
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.invitaciones ENABLE ROW LEVEL SECURITY;
-- La pantalla de registro consulta la invitacion ANTES de iniciar sesion (anon)
DROP POLICY IF EXISTS "dev_invitaciones_policy" ON public.invitaciones;
CREATE POLICY "dev_invitaciones_policy" ON public.invitaciones
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 7. GASTOS_OPERATIVOS: columnas que usa el modelo de la app
-- ---------------------------------------------------------------------
ALTER TABLE public.gastos_operativos
  ADD COLUMN IF NOT EXISTS insumo_id uuid REFERENCES public.insumos(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cantidad_usada numeric(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS costo_total numeric(12, 2) NOT NULL DEFAULT 0;
ALTER TABLE public.gastos_operativos ALTER COLUMN categoria SET DEFAULT 'General';

-- ---------------------------------------------------------------------
-- 8. Refrescar la cache de esquema de PostgREST (evita el error PGRST204)
-- ---------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
