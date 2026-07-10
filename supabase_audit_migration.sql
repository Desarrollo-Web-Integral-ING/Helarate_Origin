-- =====================================================================
-- SCRIPT DE MIGRACIÓN: AUDITORÍA AVANZADA Y LOGS PROFESIONALES
-- Proyecto: Helarate (nevero_app)
-- =====================================================================

-- 1. Agregar columna 'descripcion' a la tabla audit_logs si no existe
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS descripcion TEXT;

-- 2. Crear política para permitir la inserción de logs desde el cliente Flutter
-- (Necesario para registrar inicios/cierres de sesión y derechos ARCO)
DROP POLICY IF EXISTS "Allow insert audit logs for authenticated users" ON public.audit_logs;
CREATE POLICY "Allow insert audit logs for authenticated users" 
  ON public.audit_logs FOR INSERT 
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 3. Actualizar la función del disparador (trigger) para generar descripciones profesionales automáticas
CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    detail_msg TEXT;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        detail_msg := 'Creación de registro en la tabla ' || TG_TABLE_NAME || ' con ID: ' || COALESCE(NEW.id::text, 'N/A');
    ELSIF (TG_OP = 'UPDATE') THEN
        detail_msg := 'Actualización de registro en la tabla ' || TG_TABLE_NAME || ' con ID: ' || COALESCE(NEW.id::text, 'N/A');
    ELSIF (TG_OP = 'DELETE') THEN
        detail_msg := 'Eliminación de registro en la tabla ' || TG_TABLE_NAME || ' con ID: ' || COALESCE(OLD.id::text, 'N/A');
    ELSE
        detail_msg := 'Operación ' || TG_OP || ' en tabla ' || TG_TABLE_NAME;
    END IF;

    INSERT INTO public.audit_logs (user_id, action, table_name, record_id, descripcion)
    VALUES (
        auth.uid(),
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        detail_msg
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
