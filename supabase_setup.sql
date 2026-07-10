-- =====================================================================
-- SCRIPT DE CONFIGURACIÓN DE SEGURIDAD Y PRIVACIDAD EN SUPABASE (POSTGRESQL)
-- Proyecto: Helarate (nevero_app)
-- Cumplimiento de la Ley General de Protección de Datos Personales (LGPDPPSO)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CONTROL DE ACCESOS Y SEGURIDAD A NIVEL DE FILA (RLS) - RBAC
-- ---------------------------------------------------------------------

-- Activar RLS en todas las tablas clave de la base de datos
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insumos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_venta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gastos_operativos ENABLE ROW LEVEL SECURITY;

-- Políticas para la tabla 'profiles'
CREATE POLICY "Allow read profiles for authenticated users" 
  ON public.profiles FOR SELECT 
  USING (auth.role() = 'authenticated');
  
CREATE POLICY "Allow owners to update their own profiles" 
  ON public.profiles FOR UPDATE 
  USING (auth.uid() = id);

-- Políticas para la tabla 'insumos' (Materia Prima / Inventario)
CREATE POLICY "Allow full access to insumos for owners" 
  ON public.insumos FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'dueño'
    )
  );

CREATE POLICY "Allow read insumos for employees" 
  ON public.insumos FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'empleado'
    )
  );

CREATE POLICY "Allow write insumos for employees" 
  ON public.insumos FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'empleado'
    )
  );

CREATE POLICY "Allow update insumos for employees" 
  ON public.insumos FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'empleado'
    )
  );

-- Políticas para la tabla 'gastos_operativos' (Acceso Financiero Exclusivo de Dueños)
CREATE POLICY "Allow full access to expenses for owners" 
  ON public.gastos_operativos FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'dueño'
    )
  );

-- Políticas para la tabla 'ventas' e 'detalle_venta' (RBAC y Aislamiento por Empleado)
CREATE POLICY "Allow full access to sales for owners" 
  ON public.ventas FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'dueño'
    )
  );

CREATE POLICY "Allow employees to insert sales" 
  ON public.ventas FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'empleado'
    )
  );

CREATE POLICY "Allow employees to read their own sales" 
  ON public.ventas FOR SELECT 
  USING (
    user_id = auth.uid() AND 
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'empleado'
    )
  );

-- ---------------------------------------------------------------------
-- 2. BITÁCORA DE AUDITORÍA Y TRAZABILIDAD (SIN DATOS PERSONALES DIRECTOS)
-- ---------------------------------------------------------------------

-- Crear tabla de logs de auditoría
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID,
    action VARCHAR(20) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id UUID NOT NULL,
    descripcion TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Asegurar RLS en la tabla de logs (Solo el dueño puede auditar)
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select audit logs for owners" 
  ON public.audit_logs FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() AND profiles.rol = 'dueño'
    )
  );

CREATE POLICY "Allow insert audit logs for authenticated users" 
  ON public.audit_logs FOR INSERT 
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Función del disparador para auditoría
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

-- Enlazar Triggers de Auditoría
CREATE OR REPLACE TRIGGER insumos_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.insumos
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

CREATE OR REPLACE TRIGGER ventas_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.ventas
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

CREATE OR REPLACE TRIGGER gastos_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.gastos_operativos
FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();


-- ---------------------------------------------------------------------
-- 3. CASCADA DE BORRADO SEGURO (DERECHO DE CANCELACIÓN ARCO)
-- ---------------------------------------------------------------------

-- Función para limpiar registros públicos del usuario cuando elimina su perfil
CREATE OR REPLACE FUNCTION public.handle_profile_deleted_cascade()
RETURNS TRIGGER AS $$
BEGIN
    -- Borrado seguro en cascada de los datos relacionados al usuario
    DELETE FROM public.insumos WHERE user_id = OLD.id;
    DELETE FROM public.ventas WHERE user_id = OLD.id;
    DELETE FROM public.gastos_operativos WHERE user_id = OLD.id;
    DELETE FROM public.audit_logs WHERE user_id = OLD.id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER profile_deleted_cascade_trigger
BEFORE DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_profile_deleted_cascade();

-- Función para eliminar el usuario del esquema interno auth.users al eliminar el perfil público
CREATE OR REPLACE FUNCTION public.handle_delete_auth_user()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM auth.users WHERE id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER delete_auth_user_trigger
AFTER DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_delete_auth_user();


-- ---------------------------------------------------------------------
-- 4. CICLO DE VIDA Y RETENCIÓN DE DATOS (MINIMIZACIÓN)
-- ---------------------------------------------------------------------

-- Función para purgar datos que superen el plazo de 1 año (retención mínima)
CREATE OR REPLACE FUNCTION public.purge_expired_data()
RETURNS VOID AS $$
BEGIN
    -- Eliminar detalles de ventas antiguas
    DELETE FROM public.detalle_venta 
    WHERE venta_id IN (SELECT id FROM public.ventas WHERE fecha < NOW() - INTERVAL '1 year');
    
    -- Eliminar cabeceras de ventas antiguas
    DELETE FROM public.ventas 
    WHERE fecha < NOW() - INTERVAL '1 year';
    
    -- Eliminar gastos operativos antiguos
    DELETE FROM public.gastos_operativos 
    WHERE fecha < NOW() - INTERVAL '1 year';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
