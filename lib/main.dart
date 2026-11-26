import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'paciente_inicio.dart';
import 'paciente_login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MindjoraApp(sesionActiva: await _haySesionDePaciente()));
}

Future<bool> _haySesionDePaciente() async {
  try {
    return await PacienteAuth()
        .haySesionDePaciente()
        .timeout(const Duration(seconds: 8), onTimeout: () => false);
  } catch (_) {
    return false;
  }
}

/// Pantallas de pacientes de MINDJORA.
///
/// Arranca en el login del paciente, salvo que quede una sesión vigente: en
/// ese caso entra directo al dashboard. El registro se abre desde el enlace
/// «Crear cuenta de paciente».
class MindjoraApp extends StatelessWidget {
  const MindjoraApp({
    super.key,
    this.auth,
    this.sesionActiva = false,
  });

  final PacienteAuth? auth;

  /// `true` cuando `main()` encontró una sesión de paciente guardada.
  final bool sesionActiva;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MINDJORA · Pacientes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: sesionActiva
          ? PacienteInicioPage(auth: auth)
          : PacienteLoginPage(auth: auth),
    );
  }
}
