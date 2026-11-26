-- Direccion de contacto del paciente.
--
-- APLICAR EN EL SQL EDITOR DE SUPABASE. Es idempotente: se puede volver a aplicar.
--
-- `usuario_update_own` ya permite a cada cuenta actualizar su propia fila y el
-- trigger de la migracion 14 solo bloquea `rol` y `auth_id`, asi que no hacen
-- falta politicas nuevas para escribir esta columna.

ALTER TABLE public.usuario
  ADD COLUMN IF NOT EXISTS direccion text;

COMMENT ON COLUMN public.usuario.direccion IS
  'Direccion de contacto del usuario. Vacia si aun no la ha completado.';
