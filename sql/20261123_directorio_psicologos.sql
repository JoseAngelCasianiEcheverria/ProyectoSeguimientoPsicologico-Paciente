-- Directorio de psicólogos para el portal del paciente.
--
-- APLICAR EN EL SQL EDITOR DE SUPABASE. Es idempotente: se puede volver a aplicar.
--
-- El nombre y la foto viven en `usuario`, que el paciente no puede leer
-- directamente (bloqueo 6.1). Esta función EXPÓS SOLO nombre y foto de quienes
-- ya tienen fila en `psicologo` (alta aprobada). No expone documento, correo,
-- teléfono ni credenciales. Es SECURITY DEFINER y solo la puede ejecutar
-- `authenticated`, nunca `anon`.

CREATE OR REPLACE FUNCTION public.directorio_psicologos()
RETURNS TABLE (id_psicologo integer, nombre text, avatar_url text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id_psicologo, u.nombre, u.avatar_url
  FROM public.psicologo p
  JOIN public.usuario u ON u.id_usuario = p.id_psicologo
  WHERE u.rol = 'PSICOLOGO'::public.rol_usuario
  ORDER BY u.nombre;
$$;

REVOKE ALL ON FUNCTION public.directorio_psicologos() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.directorio_psicologos() TO authenticated;
