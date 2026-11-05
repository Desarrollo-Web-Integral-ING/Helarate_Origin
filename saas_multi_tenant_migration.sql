-- =====================================================================
-- ARQUITECTURA MAESTRA Y OPTIMIZADA AL 100% PARA SAAS Y MARCA BLANCA
-- Proyecto: Punto de Venta e Inventarios Multi-Tenant
-- Incluye:
-- 1. Ampliación de Tenants (Branding, LogoIcon, ModoOscuro, Moneda, Renta)
-- 2. Soporte de Avatar DiceBear en Perfiles
-- 3. Campos comerciales avanzados en Insumos (Código de barras, SKU)
-- 4. Soporte para Turnos y Cortes de Caja (Arqueos / Caja Registradora)
-- 5. Índices de Ultra Alta Velocidad (B-Tree en tenant_id, fechas y búsquedas)
-- 6. Aislamiento absoluto Multi-Tenant con RLS inteligente
-- 7. Integridad de Helarete asegurada (Cero pérdida de datos)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. EXTENSIÓN DE TABLA 'tenants' (Personalización y Control de Renta)
-- ---------------------------------------------------------------------
ALTER TABLE public.tenants
ADD COLUMN IF NOT EXISTS tipo_negocio text DEFAULT 'General',
ADD COLUMN IF NOT EXISTS color_primario text DEFAULT '#2563EB',
ADD COLUMN IF NOT EXISTS logo_url text NULL,
ADD COLUMN IF NOT EXISTS logo_icon text DEFAULT 'storefront',
ADD COLUMN IF NOT EXISTS modo_oscuro boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS moneda text DEFAULT '$',
ADD COLUMN IF NOT EXISTS direccion text NULL,
ADD COLUMN IF NOT EXISTS telefono text NULL,
ADD COLUMN IF NOT EXISTS mensaje_recibo text DEFAULT '¡Gracias por su compra!',
ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS fecha_vencimiento timestamp with time zone NULL;

-- ---------------------------------------------------------------------
-- 2. EXTENSIÓN DE TABLA 'profiles' (Avatares DiceBear)
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS avatar_style text DEFAULT 'notionists',
ADD COLUMN IF NOT EXISTS avatar_seed text NULL;

-- ---------------------------------------------------------------------
-- 3. CAMPOS COMERCIALES AVANZADOS EN 'insumos'
-- ---------------------------------------------------------------------
ALTER TABLE public.insumos
ADD COLUMN IF NOT EXISTS codigo_barras text NULL,
ADD COLUMN IF NOT EXISTS sku text NULL,
ADD COLUMN IF NOT EXISTS descripcion text NULL;

-- ---------------------------------------------------------------------
-- 4. TABLA DE TURNOS Y CORTE DE CAJA (ARQUEO / CORTE Z)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.turnos_caja (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  monto_apertura numeric(10, 2) NOT NULL DEFAULT 0.00,
  monto_cierre_esperado numeric(10, 2) NULL,
  monto_cierre_real numeric(10, 2) NULL,
  diferencia numeric(10, 2) NULL,
  fecha_apertura timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  fecha_cierre timestamp with time zone NULL,
  estado text NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto', 'cerrado')),
  observaciones text NULL,
  CONSTRAINT turnos_caja_pkey PRIMARY KEY (id)
);

-- Vincular opcionalmente la venta al turno de caja activo
ALTER TABLE public.ventas
ADD COLUMN IF NOT EXISTS turno_id uuid NULL REFERENCES public.turnos_caja(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS metodo_pago text DEFAULT 'efectivo' CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'transferencia', 'otro'));

-- ---------------------------------------------------------------------
-- 5. ÍNDICES DE ALTO RENDIMIENTO (OPTIMIZACIÓN QUERY PERFORMANCE)
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tenants_activo ON public.tenants(activo);

CREATE INDEX IF NOT EXISTS idx_profiles_tenant ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_rol ON public.profiles(rol);

CREATE INDEX IF NOT EXISTS idx_insumos_tenant ON public.insumos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insumos_tipo ON public.insumos(tipo);
CREATE INDEX IF NOT EXISTS idx_insumos_categoria ON public.insumos(categoria);
CREATE INDEX IF NOT EXISTS idx_insumos_codigo_barras ON public.insumos(codigo_barras) WHERE codigo_barras IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_insumos_nombre_trgm ON public.insumos USING btree (nombre);

CREATE INDEX IF NOT EXISTS idx_ventas_tenant ON public.ventas(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON public.ventas(fecha);
CREATE INDEX IF NOT EXISTS idx_ventas_turno ON public.ventas(turno_id) WHERE turno_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_detalle_venta_venta_id ON public.detalle_venta(venta_id);
CREATE INDEX IF NOT EXISTS idx_detalle_venta_insumo_id ON public.detalle_venta(insumo_id);

CREATE INDEX IF NOT EXISTS idx_turnos_caja_tenant ON public.turnos_caja(tenant_id);
CREATE INDEX IF NOT EXISTS idx_turnos_caja_estado ON public.turnos_caja(estado);

-- ---------------------------------------------------------------------
-- 6. BLINDAJE INICIAL DE HELARETE (GARANTÍA DE DATOS INTACTOS)
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_helarate_id uuid;
BEGIN
  -- Identificar o crear tenant Helarete
  SELECT id INTO v_helarate_id FROM public.tenants WHERE nombre ILIKE '%helarate%' LIMIT 1;
  IF v_helarate_id IS NULL THEN
    INSERT INTO public.tenants (nombre, tipo_negocio, color_primario, logo_icon, activo)
    VALUES ('Helarete Nevería', 'Heladería', '#2563EB', 'icecream', true)
    RETURNING id INTO v_helarate_id;
  END IF;

  -- Asignar registros huérfanos a Helarete
  UPDATE public.profiles SET tenant_id = v_helarate_id WHERE tenant_id IS NULL;
  UPDATE public.insumos SET tenant_id = v_helarate_id WHERE tenant_id IS NULL;
  UPDATE public.ventas SET tenant_id = v_helarate_id WHERE tenant_id IS NULL;
  UPDATE public.gastos_operativos SET tenant_id = v_helarate_id WHERE tenant_id IS NULL;
END $$;

-- ---------------------------------------------------------------------
-- 7. POLÍTICAS ROW LEVEL SECURITY (RLS) MULTI-TENANT
-- ---------------------------------------------------------------------
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turnos_caja ENABLE ROW LEVEL SECURITY;

-- Tenants RLS
DROP POLICY IF EXISTS "tenant_isolation_select" ON public.tenants;
CREATE POLICY "tenant_isolation_select" ON public.tenants FOR SELECT TO authenticated
USING (
  id IN (SELECT tenant_id FROM public.profiles WHERE id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND rol = 'superadmin')
);

DROP POLICY IF EXISTS "tenant_isolation_update" ON public.tenants;
CREATE POLICY "tenant_isolation_update" ON public.tenants FOR UPDATE TO authenticated
USING (
  id IN (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() AND (rol = 'dueño' OR rol = 'admin'))
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND rol = 'superadmin')
);

-- Turnos Caja RLS
DROP POLICY IF EXISTS "turnos_isolation_all" ON public.turnos_caja;
CREATE POLICY "turnos_isolation_all" ON public.turnos_caja FOR ALL TO authenticated
USING (
  tenant_id IN (SELECT tenant_id FROM public.profiles WHERE id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND rol = 'superadmin')
)
WITH CHECK (
  tenant_id IN (SELECT tenant_id FROM public.profiles WHERE id = auth.uid())
  OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND rol = 'superadmin')
);

-- ---------------------------------------------------------------------
-- 8. TRIGGER AUTOMÁTICO DE TENANT_ID
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_current_tenant_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    SELECT tenant_id INTO NEW.tenant_id
    FROM public.profiles
    WHERE id = auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_tenant_insumos ON public.insumos;
CREATE TRIGGER trg_set_tenant_insumos
BEFORE INSERT ON public.insumos
FOR EACH ROW EXECUTE FUNCTION public.set_current_tenant_id();

DROP TRIGGER IF EXISTS trg_set_tenant_ventas ON public.ventas;
CREATE TRIGGER trg_set_tenant_ventas
BEFORE INSERT ON public.ventas
FOR EACH ROW EXECUTE FUNCTION public.set_current_tenant_id();

DROP TRIGGER IF EXISTS trg_set_tenant_turnos ON public.turnos_caja;
CREATE TRIGGER trg_set_tenant_turnos
BEFORE INSERT ON public.turnos_caja
FOR EACH ROW EXECUTE FUNCTION public.set_current_tenant_id();
