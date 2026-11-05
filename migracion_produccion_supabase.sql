
-- =====================================================================
-- SCRIPT DE SINCRONIZACION COMPLETO PARA PRODUCCION (SUPABASE CLOUD / PROD)
-- =====================================================================
-- Este script es 100% IDEMPOTENTE: no borra datos existentes ni altera
-- registros ya creados. Solo agrega las tablas, columnas, relaciones,
-- politicas de seguridad (RLS) e indices que la aplicacion necesita.
--
-- Instrucciones de ejecucion:
-- 1. Ve a tu panel de Supabase en Produccion (app.supabase.com)
-- 2. Entra a tu proyecto -> SQL Editor -> New Query
-- 3. Pega todo este contenido y presiona RUN.
-- =====================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. ENUM TIPO_INSUMO
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_insumo') THEN
        CREATE TYPE public.tipo_insumo AS ENUM ('Materia Prima', 'Producto de Venta');
    END IF;
END $$;

-- 3. TABLA: TENANTS (Organizaciones / Clientes del SaaS)
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    slug TEXT UNIQUE,
    tipo_negocio TEXT NOT NULL DEFAULT 'general',
    color_primario TEXT NOT NULL DEFAULT '#2563EB',
    logo_url TEXT,
    logo_icon TEXT DEFAULT 'storefront',
    modo_oscuro BOOLEAN NOT NULL DEFAULT false,
    moneda TEXT NOT NULL DEFAULT '$',
    direccion TEXT,
    telefono TEXT,
    mensaje_recibo TEXT DEFAULT '¡Gracias por su compra!',
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_vencimiento TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Asegurar columnas si la tabla ya existia previamente
ALTER TABLE public.tenants
    ADD COLUMN IF NOT EXISTS logo_url TEXT,
    ADD COLUMN IF NOT EXISTS logo_icon TEXT DEFAULT 'storefront',
    ADD COLUMN IF NOT EXISTS modo_oscuro BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS moneda TEXT NOT NULL DEFAULT '$',
    ADD COLUMN IF NOT EXISTS direccion TEXT,
    ADD COLUMN IF NOT EXISTS telefono TEXT,
    ADD COLUMN IF NOT EXISTS mensaje_recibo TEXT DEFAULT '¡Gracias por su compra!';
ALTER TABLE public.tenants ALTER COLUMN slug DROP NOT NULL;

-- 4. TABLA: PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    email TEXT,
    nombre TEXT,
    nombre_completo TEXT,
    rol TEXT NOT NULL DEFAULT 'empleado',
    avatar_style TEXT DEFAULT 'bottts',
    avatar_seed TEXT DEFAULT 'admin',
    aceptado_aviso_at TIMESTAMPTZ,
    aviso_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Asegurar columnas en profiles si ya existia
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS nombre TEXT,
    ADD COLUMN IF NOT EXISTS avatar_style TEXT DEFAULT 'bottts',
    ADD COLUMN IF NOT EXISTS avatar_seed TEXT DEFAULT 'admin',
    ADD COLUMN IF NOT EXISTS aceptado_aviso_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS aviso_version TEXT;

-- 5. TABLA: INSUMOS / PRODUCTOS
CREATE TABLE IF NOT EXISTS public.insumos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    unidad TEXT NOT NULL DEFAULT 'pz',
    costo_unitario NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    stock_actual NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    stock_minimo NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    tipo public.tipo_insumo NOT NULL DEFAULT 'Producto de Venta'::tipo_insumo,
    precio_venta NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    user_id UUID,
    categoria TEXT NOT NULL DEFAULT 'General',
    sabor TEXT,
    tamano TEXT,
    imagen_path TEXT,
    codigo_barras TEXT,
    sku TEXT,
    descripcion TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.insumos
    ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS codigo_barras TEXT,
    ADD COLUMN IF NOT EXISTS sku TEXT,
    ADD COLUMN IF NOT EXISTS descripcion TEXT;

-- 6. TABLA: TURNOS_CAJA
CREATE TABLE IF NOT EXISTS public.turnos_caja (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID,
    nombre_cajero TEXT,
    fecha_apertura TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_cierre TIMESTAMPTZ,
    monto_inicial NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    monto_esperado NUMERIC(10, 2) DEFAULT 0.00,
    monto_real NUMERIC(10, 2),
    diferencia NUMERIC(10, 2),
    estado TEXT NOT NULL DEFAULT 'abierto',
    notas TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. TABLA: VENTAS
CREATE TABLE IF NOT EXISTS public.ventas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID,
    turno_id UUID REFERENCES public.turnos_caja(id) ON DELETE SET NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    total NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    total_ingresos NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_costos NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    metodo_pago TEXT NOT NULL DEFAULT 'efectivo',
    estado TEXT NOT NULL DEFAULT 'completada',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ventas
    ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS turno_id UUID REFERENCES public.turnos_caja(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS total_ingresos NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_costos NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'ventas'
          AND column_name = 'ganancia_neta'
    ) THEN
        ALTER TABLE public.ventas
            ADD COLUMN ganancia_neta NUMERIC(12, 2)
            GENERATED ALWAYS AS (total_ingresos - total_costos) STORED;
    END IF;
END $$;

-- 8. TABLA: DETALLE_VENTA
CREATE TABLE IF NOT EXISTS public.detalle_venta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    venta_id UUID NOT NULL REFERENCES public.ventas(id) ON DELETE CASCADE,
    insumo_id UUID REFERENCES public.insumos(id) ON DELETE SET NULL,
    cantidad NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    precio_unitario NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    precio_venta_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    costo_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.detalle_venta
    ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS precio_venta_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS costo_unitario NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 9. TABLA: GASTOS_OPERATIVOS
CREATE TABLE IF NOT EXISTS public.gastos_operativos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID,
    insumo_id UUID REFERENCES public.insumos(id) ON DELETE SET NULL,
    categoria TEXT NOT NULL DEFAULT 'General',
    monto NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    cantidad_usada NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    costo_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    descripcion TEXT,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.gastos_operativos
    ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS insumo_id UUID REFERENCES public.insumos(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS cantidad_usada NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS costo_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00;

-- 10. TABLA: AUDIT_LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID,
    descripcion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. TABLA: INVITACIONES
CREATE TABLE IF NOT EXISTS public.invitaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    nombre TEXT,
    email TEXT NOT NULL,
    rol TEXT NOT NULL DEFAULT 'empleado',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. INDICES DE RENDIMIENTO MULTI-TENANT
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insumos_tenant_id ON public.insumos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insumos_codigo_barras ON public.insumos(codigo_barras);
CREATE INDEX IF NOT EXISTS idx_ventas_tenant_id ON public.ventas(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON public.ventas(fecha);
CREATE INDEX IF NOT EXISTS idx_detalle_venta_tenant_id ON public.detalle_venta(tenant_id);
CREATE INDEX IF NOT EXISTS idx_turnos_caja_tenant_id ON public.turnos_caja(tenant_id);
CREATE INDEX IF NOT EXISTS idx_gastos_operativos_tenant_id ON public.gastos_operativos(tenant_id);

-- 13. HABILITACION DE RLS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insumos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_venta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turnos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gastos_operativos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitaciones ENABLE ROW LEVEL SECURITY;

-- 14. POLÍTICAS RLS AISLADAS POR TENANT (PRODUCCION)
-- Funcion auxiliar para obtener el tenant_id del usuario autenticado
CREATE OR REPLACE FUNCTION public.current_user_tenant_id()
RETURNS UUID AS $$
    SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Tenants: cada usuario ve y edita su propio tenant
DROP POLICY IF EXISTS "tenant_isolation_policy" ON public.tenants;
CREATE POLICY "tenant_isolation_policy" ON public.tenants
    FOR ALL TO authenticated
    USING (id = public.current_user_tenant_id())
    WITH CHECK (id = public.current_user_tenant_id());

-- Profiles: usuario ve miembros de su propio tenant
DROP POLICY IF EXISTS "profiles_isolation_policy" ON public.profiles;
CREATE POLICY "profiles_isolation_policy" ON public.profiles
    FOR ALL TO authenticated
    USING (tenant_id = public.current_user_tenant_id() OR id = auth.uid())
    WITH CHECK (tenant_id = public.current_user_tenant_id() OR id = auth.uid());

-- Insumos
DROP POLICY IF EXISTS "insumos_isolation_policy" ON public.insumos;
CREATE POLICY "insumos_isolation_policy" ON public.insumos
    FOR ALL TO authenticated
    USING (tenant_id = public.current_user_tenant_id())
    WITH CHECK (tenant_id = public.current_user_tenant_id());

-- Ventas
DROP POLICY IF EXISTS "ventas_isolation_policy" ON public.ventas;
CREATE POLICY "ventas_isolation_policy" ON public.ventas
    FOR ALL TO authenticated
    USING (tenant_id = public.current_user_tenant_id())
    WITH CHECK (tenant_id = public.current_user_tenant_id());

-- Detalle de Venta
DROP POLICY IF EXISTS "detalle_venta_isolation_policy" ON public.detalle_venta;
CREATE POLICY "detalle_venta_isolation_policy" ON public.detalle_venta
    FOR ALL TO authenticated
    USING (tenant_id = public.current_user_tenant_id())
    WITH CHECK (tenant_id = public.current_user_tenant_id());

-- Turnos Caja
DROP POLICY IF EXISTS "turnos_caja_isolation_policy" ON public.turnos_caja;
CREATE POLICY "turnos_caja_isolation_policy" ON public.turnos_caja
    FOR ALL TO authenticated
    USING (tenant_id = public.current_user_tenant_id())
    WITH CHECK (tenant_id = public.current_user_tenant_id());

-- Gastos Operativos
DROP POLICY IF EXISTS "gastos_isolation_policy" ON public.gastos_operativos;
CREATE POLICY "gastos_isolation_policy" ON public.gastos_operativos
    FOR ALL TO authenticated
    USING (tenant_id = public.current_user_tenant_id())
    WITH CHECK (tenant_id = public.current_user_tenant_id());

-- Audit logs
DROP POLICY IF EXISTS "audit_logs_isolation_policy" ON public.audit_logs;
CREATE POLICY "audit_logs_isolation_policy" ON public.audit_logs
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Invitaciones
DROP POLICY IF EXISTS "invitaciones_policy" ON public.invitaciones;
CREATE POLICY "invitaciones_policy" ON public.invitaciones
    FOR ALL TO anon, authenticated
    USING (true)
    WITH CHECK (true);

-- 15. TRIGGER DE REGISTRO AUTOMÁTICO
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    target_tenant_id UUID;
    display_name TEXT;
    invitation_record RECORD;
BEGIN
    display_name := COALESCE(
        NEW.raw_user_meta_data->>'nombre',
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1)
    );

    -- Revisar si el usuario viene por una invitación previa
    SELECT * INTO invitation_record FROM public.invitaciones WHERE LOWER(email) = LOWER(NEW.email) LIMIT 1;

    IF invitation_record.id IS NOT NULL THEN
        target_tenant_id := invitation_record.tenant_id;
    ELSE
        -- Si no hay invitación y el usuario no especificó tenant, usar o crear su tenant default
        SELECT id INTO target_tenant_id FROM public.tenants WHERE slug = 'helarate' LIMIT 1;
        IF target_tenant_id IS NULL THEN
            INSERT INTO public.tenants (nombre, slug, tipo_negocio, color_primario, modo_oscuro, moneda)
            VALUES ('Mi Negocio', 'default-' || substr(NEW.id::text, 1, 8), 'general', '#2563EB', false, '$')
            RETURNING id INTO target_tenant_id;
        END IF;
    END IF;

    INSERT INTO public.profiles (id, email, nombre, nombre_completo, rol, tenant_id, avatar_style, avatar_seed)
    VALUES (
        NEW.id,
        NEW.email,
        display_name,
        display_name,
        COALESCE(invitation_record.rol, NEW.raw_user_meta_data->>'rol', 'dueño'),
        target_tenant_id,
        'bottts',
        NEW.id::text
    )
    ON CONFLICT (id) DO UPDATE SET
        tenant_id = COALESCE(public.profiles.tenant_id, EXCLUDED.tenant_id),
        nombre = COALESCE(public.profiles.nombre, EXCLUDED.nombre);

    -- Borrar invitacion procesada
    IF invitation_record.id IS NOT NULL THEN
        DELETE FROM public.invitaciones WHERE id = invitation_record.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 16. RECARGAR CACHÉ DE POSTGREST
NOTIFY pgrst, 'reload schema';



-- 10. MODULO DE CAMPOS PERSONALIZADOS PARA INVENTARIO
CREATE TABLE IF NOT EXISTS public.campos_personalizados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    tipo_dato TEXT NOT NULL DEFAULT 'texto',
    opciones JSONB DEFAULT '[]'::jsonb,
    obligatorio BOOLEAN NOT NULL DEFAULT false,
    aplica_a TEXT NOT NULL DEFAULT 'todos',
    orden INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Asegurar columna atributos (JSONB) en la tabla insumos para soportar campos libres
ALTER TABLE public.insumos ADD COLUMN IF NOT EXISTS atributos JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.campos_personalizados ENABLE ROW LEVEL SECURITY;

DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'campos_personalizados' AND policyname = 'campos_personalizados_tenant_isolation'
    ) THEN
        CREATE POLICY campos_personalizados_tenant_isolation ON public.campos_personalizados
            FOR ALL USING (
                tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid())
            );
    END IF;
END \$\$;
