-- =====================================================================
-- SCRIPT DEFINITIVO Y UNIFICADO DE CONFIGURACIÓN Y FIX DE BASE DE DATOS
-- Proyecto: Helarate (nevero_app - Supabase PostgreSQL)
-- Incluye: Lectura, Escritura, Borrado (DELETE), Cascadas (CASCADE) y RLS
-- =====================================================================

-- 1. Crear el tipo Enum 'tipo_insumo' si no existe
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_insumo') THEN
        CREATE TYPE public.tipo_insumo AS ENUM ('Materia Prima', 'Producto de Venta');
    END IF;
END $$;

-- 2. Asegurar que la tabla public.insumos exista
CREATE TABLE IF NOT EXISTS public.insumos (
  id uuid NOT NULL DEFAULT gen_random_uuid (),
  nombre text NOT NULL,
  unidad text NOT NULL,
  costo_unitario numeric(10, 2) NOT NULL DEFAULT 0.00,
  stock_actual numeric(10, 2) NOT NULL DEFAULT 0.00,
  stock_minimo numeric(10, 2) NOT NULL DEFAULT 0.00,
  tipo public.tipo_insumo NOT NULL DEFAULT 'Materia Prima'::tipo_insumo,
  precio_venta numeric(10, 2) NOT NULL DEFAULT 0.00,
  user_id uuid NULL,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone ('utc'::text, now()),
  categoria text NOT NULL DEFAULT 'General'::text,
  sabor text NULL,
  tamano text NULL,
  imagen_path text NULL,
  CONSTRAINT insumos_pkey PRIMARY KEY (id)
);

-- 3. Ajustar la columna 'fecha' a DATE en public.ventas para compatibilidad con PostgREST
ALTER TABLE public.ventas 
ALTER COLUMN fecha TYPE DATE 
USING fecha::date;

-- 4. Habilitar borrado en cascada (ON DELETE CASCADE) de detalle_venta al borrar en ventas
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'detalle_venta_venta_id_fkey'
  ) THEN
    ALTER TABLE public.detalle_venta DROP CONSTRAINT detalle_venta_venta_id_fkey;
  END IF;
END $$;

ALTER TABLE public.detalle_venta
ADD CONSTRAINT detalle_venta_venta_id_fkey 
FOREIGN KEY (venta_id) REFERENCES public.ventas(id) ON DELETE CASCADE;

-- 5. Sincronizar perfiles en public.profiles para todos los usuarios en auth.users
INSERT INTO public.profiles (id, email, nombre_completo, rol)
SELECT 
    id, 
    email, 
    COALESCE(raw_user_meta_data->>'full_name', split_part(email, '@', 1)) AS nombre_completo, 
    'dueño' AS rol
FROM auth.users
ON CONFLICT (id) DO UPDATE 
SET rol = EXCLUDED.rol;

-- 6. Habilitar Políticas RLS Abiertas (SELECT, INSERT, UPDATE, DELETE) para Usuarios Autenticados

-- Políticas para 'insumos'
DROP POLICY IF EXISTS "Allow authenticated read insumos" ON public.insumos;
CREATE POLICY "Allow authenticated read insumos" ON public.insumos FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated write insumos" ON public.insumos;
CREATE POLICY "Allow authenticated write insumos" ON public.insumos FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated update insumos" ON public.insumos;
CREATE POLICY "Allow authenticated update insumos" ON public.insumos FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated delete insumos" ON public.insumos;
CREATE POLICY "Allow authenticated delete insumos" ON public.insumos FOR DELETE TO authenticated USING (true);

-- Políticas para 'ventas'
DROP POLICY IF EXISTS "Allow authenticated read ventas" ON public.ventas;
CREATE POLICY "Allow authenticated read ventas" ON public.ventas FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated insert ventas" ON public.ventas;
CREATE POLICY "Allow authenticated insert ventas" ON public.ventas FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated delete ventas" ON public.ventas;
CREATE POLICY "Allow authenticated delete ventas" ON public.ventas FOR DELETE TO authenticated USING (true);

-- Políticas para 'detalle_venta'
DROP POLICY IF EXISTS "Allow authenticated read detalle_venta" ON public.detalle_venta;
CREATE POLICY "Allow authenticated read detalle_venta" ON public.detalle_venta FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated insert detalle_venta" ON public.detalle_venta;
CREATE POLICY "Allow authenticated insert detalle_venta" ON public.detalle_venta FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated delete detalle_venta" ON public.detalle_venta;
CREATE POLICY "Allow authenticated delete detalle_venta" ON public.detalle_venta FOR DELETE TO authenticated USING (true);

-- 7. Poblado de Productos de Prueba para todos los Usuarios Autenticados

-- Producto CN-01: Helado de Vainilla 1/2 Litro (Stock 20, Precio $45.00)
INSERT INTO public.insumos (
  nombre, unidad, costo_unitario, stock_actual, stock_minimo, 
  tipo, precio_venta, categoria, sabor, tamano, user_id
)
SELECT 
  'Helado de Vainilla', 'Pieza', 25.00, 20.00, 5.00,
  'Producto de Venta'::public.tipo_insumo, 45.00, 'Helados', 'Vainilla', '1/2 Litro',
  u.id
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.insumos i WHERE i.nombre = 'Helado de Vainilla' AND i.user_id = u.id
);

-- Producto CN-02: Paleta de Mango (Stock 5, Precio $20.00)
INSERT INTO public.insumos (
  nombre, unidad, costo_unitario, stock_actual, stock_minimo, 
  tipo, precio_venta, categoria, sabor, tamano, user_id
)
SELECT 
  'Paleta de Mango', 'Pieza', 10.00, 5.00, 2.00,
  'Producto de Venta'::public.tipo_insumo, 20.00, 'Paletas', 'Mango', 'Estándar',
  u.id
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.insumos i WHERE i.nombre = 'Paleta de Mango' AND i.user_id = u.id
);

-- Actualizar insumos existentes con user_id NULL
UPDATE public.insumos 
SET user_id = (SELECT id FROM auth.users ORDER BY created_at ASC LIMIT 1)
WHERE user_id IS NULL;

-- 8. Consulta de verificación final
SELECT 
    v.id AS venta_id, 
    v.fecha, 
    v.total_ingresos, 
    v.user_id,
    d.id AS detalle_id,
    d.insumo_id,
    d.cantidad,
    d.precio_venta_unitario
FROM public.ventas v
LEFT JOIN public.detalle_venta d ON d.venta_id = v.id;
