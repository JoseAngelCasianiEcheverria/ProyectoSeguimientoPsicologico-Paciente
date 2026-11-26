import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Cliente de Supabase, inicializado una sola vez.
///
/// Por que una clase y no una variable global suelta: `initialize` es asincrono
/// y se llama desde `main`. Si dos widgets lo llaman a la vez, se crean dos
/// clientes y se pierde el estado de sesion. Aqui la promesa queda cacheada.
class AppSupabase {
  const AppSupabase._();

  static SupabaseClient? _client;

  /// Devuelve el cliente, inicializandolo la primera vez.
  ///
  /// Lanza [AppConfigException] si faltan las credenciales. Es preferible
  /// fallar de forma explicita que devolver un cliente que nunca va a
  /// conectar.
  static Future<SupabaseClient> instance() async {
    final existente = _client;
    if (existente != null) return existente;

    if (!AppConfig.isConfigured) {
      throw AppConfigException(AppConfig.missingReason);
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // La publishable key concede el rol `anon`. No confia nada por si misma:
      // lo que un usuario puede ver lo deciden las politicas RLS de la base.
      publishableKey: AppConfig.supabasePublishableKey,
    );

    _client = Supabase.instance.client;
    return _client!;
  }

  /// Permite inyectar un cliente en tests sin tocar la red.
  ///
  /// Los tests no usan Supabase real: por eso `reset()` existe. Sin el, el
  /// cliente cacheado se filtra entre tests y el segundo test usa el cliente
  /// del primero.
  @visibleForTesting
  static void overrideWith(SupabaseClient client) => _client = client;

  /// Limpia el cliente cacheado.
  ///
  /// No es solo para tests: cerrar sesion necesita olvidar el cliente, porque
  /// si no la siguiente persona que entre en el mismo navegador heredaria la
  /// sesion anterior.
  static void reset() => _client = null;

  /// `true` si ya se inicializo, sin dispararla.
  static bool get isInitialized => _client != null;

  /// Cierra la sesion y limpia el cliente cacheado.
  static Future<void> signOut() async {
    final cliente = _client;
    if (cliente == null) return;
    await cliente.auth.signOut();
    _client = null;
  }
}

/// Falta de configuracion de la conexion.
class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}