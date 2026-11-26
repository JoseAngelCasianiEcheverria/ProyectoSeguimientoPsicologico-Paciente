-- Fix: un horario reservado seguia apareciendo DISPONIBLE para otros pacientes.
--
-- Causa: `reservar_slot` protegia la doble reserva con el indice unico
-- parcial, pero dejaba `disponibilidad.estado = 'DISPONIBLE'`. La agenda del
-- paciente mostraba entonces huecos ya tomados y la reserva fallaba con
-- "Ese horario acaba de ser reservado por otra persona" (23505).
--
-- Este script:
--   1. Marca NO_DISPONIBLE los huecos que ya tienen una cita vigente.
--   2. Hace que `reservar_slot` marque el hueco al reservar y rechace fechas
--      pasadas (el indice unico ya existente sigue como ultima defensa).
--   3. Reabre el hueco si la cita se cancela.
--
-- APLICAR EN EL SQL EDITOR DE SUPABASE (proyecto ertrvlmjpcrjgfwqeglu).
-- Es idempotente: se puede volver a ejecutar.

-- 1. Limpieza de datos: huecos ya tomados por una cita vigente.
UPDATE public.disponibilidad d
SET estado = 'NO_DISPONIBLE'
WHERE d.estado = 'DISPONIBLE'
  AND EXISTS (
    SELECT 1
    FROM public.cita c
    WHERE c.id_disponibilidad = d.id_disponibilidad
      AND c.estado_cita <> 'CANCELADA'
  );

-- 2. `reservar_slot`: mismo contrato de la migracion 10, mas el bloqueo del
--    hueco y el rechazo de fechas pasadas.
CREATE OR REPLACE FUNCTION public.reservar_slot(
  p_id_paciente       integer,
  p_id_psicologo      integer,
  p_id_disponibilidad integer,
  p_modalidad         public.tipo_modalidad DEFAULT 'PRESENCIAL',
  p_motivo_consulta   text                   DEFAULT NULL
)
RETURNS public.cita
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_cita    public.cita;
  v_horario timestamptz;
  v_yo      integer;
BEGIN
  v_yo := (SELECT public.mi_usuario_id());

  IF v_yo IS NULL THEN
    RAISE EXCEPTION 'Sesion no autenticada.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_id_paciente IS DISTINCT FROM v_yo THEN
    RAISE EXCEPTION 'Solo puede reservar sobre su propia cuenta.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT d.fecha_hora_inicio
  INTO v_horario
  FROM public.disponibilidad d
  WHERE d.id_disponibilidad = p_id_disponibilidad
    AND d.id_psicologo = p_id_psicologo
    AND d.estado = 'DISPONIBLE';

  IF v_horario IS NULL THEN
    RAISE EXCEPTION
      'El horario no existe, no pertenece a ese profesional, o ya no esta disponible.'
      USING ERRCODE = 'check_violation';
  END IF;

  IF v_horario < now() THEN
    RAISE EXCEPTION 'El horario ya paso.'
      USING ERRCODE = 'check_violation';
  END IF;

  BEGIN
    INSERT INTO public.cita (
      id_paciente, id_psicologo, id_disponibilidad, fecha_hora,
      estado_cita, modalidad, motivo_consulta
    )
    VALUES (
      p_id_paciente, p_id_psicologo, p_id_disponibilidad, v_horario,
      'PENDIENTE', p_modalidad, p_motivo_consulta
    )
    RETURNING * INTO v_cita;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Ese horario acaba de ser reservado por otra persona.'
        USING ERRCODE = 'unique_violation';
  END;

  UPDATE public.disponibilidad
  SET estado = 'NO_DISPONIBLE'
  WHERE id_disponibilidad = p_id_disponibilidad;

  RETURN v_cita;
END
$function$;

-- 3. Mantener el hueco sincronizado con el estado de la cita.
CREATE OR REPLACE FUNCTION public.sincronizar_slot_con_cita()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NEW.id_disponibilidad IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.estado_cita = 'CANCELADA' THEN
    UPDATE public.disponibilidad
    SET estado = 'DISPONIBLE'
    WHERE id_disponibilidad = NEW.id_disponibilidad;
  ELSE
    UPDATE public.disponibilidad
    SET estado = 'NO_DISPONIBLE'
    WHERE id_disponibilidad = NEW.id_disponibilidad;
  END IF;

  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS cita_sincroniza_slot ON public.cita;
CREATE TRIGGER cita_sincroniza_slot
AFTER INSERT OR UPDATE OF estado_cita ON public.cita
FOR EACH ROW
EXECUTE FUNCTION public.sincronizar_slot_con_cita();

-- Comprobacion: no debe quedar ningun hueco DISPONIBLE con cita vigente.
SELECT count(*) AS huecos_tomados_visibles
FROM public.disponibilidad d
JOIN public.cita c ON c.id_disponibilidad = d.id_disponibilidad
WHERE d.estado = 'DISPONIBLE'
  AND c.estado_cita <> 'CANCELADA';
