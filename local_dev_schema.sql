-- NOTA: despues de ejecutar este esquema base, ejecuta tambien
-- migracion_alinear_esquema_app.sql (agrega las columnas que la app necesita,
-- p. ej. ventas.total_costos).
-- =====================================================================
-- ESQUEMA COMPLETO LOCAL Y SAAS MULTI-TENANT PARA DESARROLLO (DOCKER)
-- =====================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TIPOS ENUM
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
    slug TEXT UNIQUE NOT NULL,
    tipo_negocio TEXT NOT NULL DEFAULT 'neveria',
    color_primario TEXT NOT NULL DEFAULT '#EC4899',
    logo_url TEXT,
    logo_icon TEXT DEFAULT 'icecream',
    modo_oscuro BOOLEAN NOT NULL DEFAULT false,
    moneda TEXT NOT NULL DEFAULT 'MXN',
    direccion TEXT,
    telefono TEXT,
    mensaje_recibo TEXT DEFAULT '¡Gracias por su compra!',
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_vencimiento TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Inquilino por defecto: Helarate
INSERT INTO public.tenants (nombre, slug, tipo_negocio, color_primario, logo_icon, modo_oscuro, moneda, mensaje_recibo)
VALUES ('Helarate', 'helarate', 'neveria', '#EC4899', 'icecream', false, 'MXN', '¡Gracias por su compra en Helarate!')
ON CONFLICT (slug) DO NOTHING;

-- 4. TABLA: PROFILES (Usuarios)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    email TEXT,
    nombre_completo TEXT,
    rol TEXT NOT NULL DEFAULT 'empleado',
    avatar_style TEXT DEFAULT 'bottts',
    avatar_seed TEXT DEFAULT 'admin',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

-- 6. TABLA: TURNOS DE CAJA
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
    metodo_pago TEXT NOT NULL DEFAULT 'efectivo',
    estado TEXT NOT NULL DEFAULT 'completada',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. TABLA: DETALLE_VENTA
CREATE TABLE IF NOT EXISTS public.detalle_venta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    venta_id UUID NOT NULL REFERENCES public.ventas(id) ON DELETE CASCADE,
    insumo_id UUID REFERENCES public.insumos(id) ON DELETE SET NULL,
    cantidad NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    precio_unitario NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. TABLA: GASTOS OPERATIVOS
CREATE TABLE IF NOT EXISTS public.gastos_operativos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID,
    categoria TEXT NOT NULL,
    monto NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    descripcion TEXT,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. ÍNDICES DE RENDIMIENTO MULTI-TENANT
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insumos_tenant_id ON public.insumos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_insumos_codigo_barras ON public.insumos(codigo_barras);
CREATE INDEX IF NOT EXISTS idx_ventas_tenant_id ON public.ventas(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON public.ventas(fecha);
CREATE INDEX IF NOT EXISTS idx_detalle_venta_tenant_id ON public.detalle_venta(tenant_id);
CREATE INDEX IF NOT EXISTS idx_turnos_caja_tenant_id ON public.turnos_caja(tenant_id);

-- 11. HABILITAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insumos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_venta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turnos_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gastos_operativos ENABLE ROW LEVEL SECURITY;

-- 12. POLÍTICAS PERMISIVAS PARA AUTENTICADOS EN DEV
DROP POLICY IF EXISTS "dev_tenants_policy" ON public.tenants;
CREATE POLICY "dev_tenants_policy" ON public.tenants FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "dev_profiles_policy" ON public.profiles;
CREATE POLICY "dev_profiles_policy" ON public.profiles FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "dev_insumos_policy" ON public.insumos;
CREATE POLICY "dev_insumos_policy" ON public.insumos FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "dev_ventas_policy" ON public.ventas;
CREATE POLICY "dev_ventas_policy" ON public.ventas FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "dev_detalle_policy" ON public.detalle_venta;
CREATE POLICY "dev_detalle_policy" ON public.detalle_venta FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "dev_turnos_policy" ON public.turnos_caja;
CREATE POLICY "dev_turnos_policy" ON public.turnos_caja FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "dev_gastos_policy" ON public.gastos_operativos;
CREATE POLICY "dev_gastos_policy" ON public.gastos_operativos FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 13. FUNCIÓN Y TRIGGER PARA ASOCIAR NUEVOS USUARIOS AL TENANT POR DEFECTO
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_tenant_id UUID;
BEGIN
    SELECT id INTO default_tenant_id FROM public.tenants WHERE slug = 'helarate' LIMIT 1;
    
    INSERT INTO public.profiles (id, email, nombre_completo, rol, tenant_id, avatar_style, avatar_seed)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'rol', 'dueño'),
        default_tenant_id,
        'bottts',
        NEW.id::text
    )
    ON CONFLICT (id) DO UPDATE SET
        tenant_id = COALESCE(public.profiles.tenant_id, EXCLUDED.tenant_id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Datos semilla de prueba para el tenant Helarate
DO $$
DECLARE
    hel_tenant_id UUID;
BEGIN
    SELECT id INTO hel_tenant_id FROM public.tenants WHERE slug = 'helarate' LIMIT 1;

    INSERT INTO public.insumos (tenant_id, nombre, unidad, costo_unitario, stock_actual, stock_minimo, tipo, precio_venta, categoria, sabor, tamano)
    VALUES 
    (hel_tenant_id, 'Nieve de Fresa', 'litro', 25.00, 50.00, 10.00, 'Producto de Venta', 60.00, 'Nieves', 'Fresa', '1L'),
    (hel_tenant_id, 'Nieve de Vainilla', 'litro', 22.00, 45.00, 10.00, 'Producto de Venta', 55.00, 'Nieves', 'Vainilla', '1L'),
    (hel_tenant_id, 'Paleta de Chocolate', 'pz', 8.00, 100.00, 20.00, 'Producto de Venta', 20.00, 'Paletas', 'Chocolate', 'Individual'),
    (hel_tenant_id, 'Conos de Galleta', 'caja', 50.00, 15.00, 5.00, 'Materia Prima', 0.00, 'Insumos', null, 'Caja 100pz')
    ON CONFLICT DO NOTHING;
END $$;

