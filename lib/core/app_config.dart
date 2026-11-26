import 'package:flutter/foundation.dart';

/// Configuracion de la conexion a Supabase.
///
/// Los valores llegan en tiempo de compilacion con
/// `--dart-define-from-file=.env`:
///
/// ```
/// flutter run --dart-define-from-file=.env
/// flutter build web --dart-define-from-file=.env
/// ```
///
/// Por que `String.fromEnvironment` y no `flutter_dotenv`: evita una
/// dependencia, funciona igual en web, Android e iOS, y no deja el archivo
/// `.env` embebido en el bundle de produccion. El costo es que cambiar la
/// clave exige recompilar, no basta con recargar.
///
/// La clave se lee en debug con `assert` para que un developerse entere rapido
/// de que falto el `--dart-define-from-file`, en vez de ver un error de red
/// veinte segundos despues.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

  /// Id del psicologo que se muestra al entrar.
  ///
  /// ## Provisional, y por que
  ///
  /// El login de la app todavia no autentica: valida que los campos no esten
  /// vacios y navega. Sin sesion no hay forma de saber quien entro, asi que
  /// el id viaja por configuracion.
  ///
  /// Cuando exista autenticacion real, esto se reemplaza por el RPC
  /// `mi_psicologo_id()` que ya esta en la base. Ese es el camino correcto y
  /// ya funciona con RLS: `public.mi_psicologo_id()` devuelve
  /// `psicologo.id_psicologo` del usuario autenticado, y `null` si la sesion
  /// no corresponde a un psicologo.
  ///
  /// Ojo: es un id de la base, no un nombre. Cambia si se resiembra con otro
  /// orden de insercion. Por eso va en `.env` y no como constante en el codigo.
  static const String idPsicologoDemo =
      String.fromEnvironment('ID_PSICOLOGO', defaultValue: '');

  /// `true` cuando hay URL y clave. Se consulta antes de tocar la red.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Descripcion del problema, para mostrarla en la app o en un test.
  static String get missingReason {
    if (supabaseUrl.isEmpty && supabasePublishableKey.isEmpty) {
      return 'Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.';
    }
    if (supabaseUrl.isEmpty) return 'Falta SUPABASE_URL.';
    return 'Falta SUPABASE_PUBLISHABLE_KEY.';
  }

  /// Aviso de arranque. Silencioso cuando todo esta bien.
  ///
  /// Solo imprime en debug a proposito: en produccion un `print` puede ir a
  /// los logs del navegador y del servidor de forma visible.
  static void warnIfUnconfigured() {
    if (isConfigured) return;
    assert(() {
      debugPrint(
        '[Mindjora] $missingReason\n'
        'Copia .env.example a .env y arranca con '
        '`flutter run --dart-define-from-file=.env`.',
      );
      return true;
    }());
  }
}