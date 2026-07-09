-- =====================================================================
-- SCRIPT SQL: RESTRICCIONES CHECK DE INTEGRIDAD Y SEGURIDAD
-- Proyecto: Helarate (nevero_app)
-- Issue: [SECURITY-2] Implementar CHECK Constraints en Postgres
-- =====================================================================

-- 1. Restricciones para la tabla 'profiles' (Perfiles de usuario)
-- Nos aseguramos de que exista la columna 'email' si se desea validar
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Eliminar restricción previa si existe para evitar conflictos
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_email_format;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_profile_nombre_length;

-- Añadir restricción CHECK para validar el formato del correo electrónico mediante Regex
ALTER TABLE public.profiles ADD CONSTRAINT check_email_format 
  CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Añadir restricción CHECK para validar longitud del nombre (entre 3 y 100 caracteres sin espacios vacíos al inicio/final)
ALTER TABLE public.profiles ADD CONSTRAINT check_profile_nombre_length 
  CHECK (char_length(trim(nombre)) >= 3 AND char_length(trim(nombre)) <= 100);



-- 2. Restricciones para la tabla 'insumos' (Insumos / Productos de Venta)
-- Eliminar restricciones previas
ALTER TABLE public.insumos DROP CONSTRAINT IF EXISTS check_insumo_nombre_length;
ALTER TABLE public.insumos DROP CONSTRAINT IF EXISTS check_insumo_valores_positivos;

-- Añadir restricción CHECK para validar longitud del nombre (entre 3 y 100 caracteres sin espacios vacíos al inicio/final)
ALTER TABLE public.insumos ADD CONSTRAINT check_insumo_nombre_length 
  CHECK (char_length(trim(nombre)) >= 3 AND char_length(trim(nombre)) <= 100);

-- Añadir restricción CHECK para asegurar que costos, precios y existencias no sean negativos
ALTER TABLE public.insumos ADD CONSTRAINT check_insumo_valores_positivos 
  CHECK (costo_unitario >= 0 AND stock_actual >= 0 AND stock_minimo >= 0 AND precio_venta >= 0);


-- 3. Restricciones adicionales para la tabla 'gastos_operativos' (Trazabilidad financiera)
ALTER TABLE public.gastos_operativos DROP CONSTRAINT IF EXISTS check_gasto_valores_positivos;

-- Asegurar que las cantidades de insumos usados y el costo total de los gastos no sean negativos
ALTER TABLE public.gastos_operativos ADD CONSTRAINT check_gasto_valores_positivos 
  CHECK (cantidad_usada >= 0 AND costo_total >= 0);
