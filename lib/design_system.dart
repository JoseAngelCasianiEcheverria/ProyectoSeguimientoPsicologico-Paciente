import 'package:flutter/material.dart';

/// Colores, tipografías y textos legal de las vistas de pacientes.
///
/// Los valores salen de las capturas de diseño entregadas:
/// * Vista 2: Registro de Paciente
/// * Vista 18: Login Psicólogo (adaptada a Login Paciente)
///
/// El verde de marca (#2F5D50) es el del botón principal y del interruptor
/// de las vistas; el resto son neutros muestreados del lienzo.
abstract final class AppColors {
  /// Verde de marca: botones, interruptores y acentos.
  static const Color brand = Color(0xFF2F5D50);

  /// Verde casi negro para titulares y la marca MINDJORA.
  static const Color brandDark = Color(0xFF24473C);

  /// Verde muy claro para píldoras de estado.
  static const Color brandSoft = Color(0xFFE7F1EF);

  /// Fondo de página de los formularios.
  static const Color canvas = Color(0xFFF4F6F5);

  /// Fondo crema de las pantallas de acceso.
  static const Color cream = Color(0xFFF4F1EA);

  /// Tarjeta crema que envuelve el formulario de acceso.
  static const Color creamCard = Color(0xFFFAF8F3);

  /// Sub-bloque crema del interruptor de verificación en dos pasos.
  static const Color creamSoft = Color(0xFFF1EDE3);

  static const Color creamBorder = Color(0xFFE6E1D6);

  /// Texto principal.
  static const Color text = Color(0xFF2B3130);

  /// Texto secundario: subtítulos y descripciones.
  static const Color textSoft = Color(0xFF6F7781);

  /// Texto terciario: sugerencias de los campos.
  static const Color textFaint = Color(0xFF9AA1A8);

  static const Color border = Color(0xFFE3E5E0);

  static const Color divider = Color(0xFFEDEEEC);

  // --- Vista de especialistas ----------------------------------------------
  // El directorio se aparta de la paleta crema del panel: lienzo casi blanco,
  // tinta pizarra en los titulares y una gama neutra para los chips. Los
  // acentos (botones, «CUIDADO CLÍNICO», «Zona horaria local») siguen siendo
  // el verde de la marca.

  /// Tinta de titulares y nombres de profesional: pizarra, no verde.
  static const Color ink = Color(0xFF1F2A33);

  /// Subtítulos dentro de las tarjetas: rol, años de experiencia, precio aprox.
  static const Color inkSoft = Color(0xFF5B6672);

  /// Fondo de los chips sin seleccionar y de la banda de modalidad.
  static const Color chipBg = Color(0xFFF1F2F0);

  /// Fondo del bloque de disponibilidad y del aviso del pie.
  static const Color softFill = Color(0xFFF6F7F6);

  /// Día seleccionado de la tira de fechas.
  static const Color dayActive = Color(0xFF33465B);

  /// Punto de disponibilidad bajo un día con horarios.
  static const Color dot = Color(0xFFC4C9C3);

  /// Estrella de la valoración.
  static const Color star = Color(0xFFD9A441);

  /// Fondo del aviso de privacidad del pie.
  static const Color noticeBg = Color(0xFFEFF2F2);

  static const Color error = Color(0xFFB84F4F);

  // --- Paleta del panel en modo oscuro -------------------------------------
  // El panel del paciente es la primera vista con interruptor de tema, así que
  // necesita su propia gama oscura. Vive aquí para no repetir hex en las vistas.

  /// Fondo de página del panel en modo oscuro.
  static const Color darkCanvas = Color(0xFF141B19);

  /// Tarjetas: cita, evaluaciones, tareas y acompañante.
  static const Color darkCard = Color(0xFF1E2725);

  static const Color darkCardBorder = Color(0xFF2F3A37);

  /// Sub-bloque dentro de una tarjeta: horario de la cita, botón secundario.
  static const Color darkSoft = Color(0xFF26302D);

  static const Color darkSoftBorder = Color(0xFF37423F);

  /// Chip de ánimo seleccionado.
  static const Color darkAccent = Color(0xFF2C4840);

  static const Color darkAccentBorder = Color(0xFF4C6F64);

  /// Titulares y texto principal del modo oscuro.
  static const Color darkTextStrong = Color(0xFFE5ECEA);

  static const Color darkTextBody = Color(0xFFA9B5B1);

  static const Color darkTextFaint = Color(0xFF7D8985);

  /// Verde de acento (iconos y barras) legible sobre fondo oscuro.
  static const Color darkBrand = Color(0xFF8FC8B3);

  /// Verde de los botones principales, algo más claro que en modo claro.
  static const Color darkBrandFill = Color(0xFF3E7D6C);

  /// Píldoras de estado: «En 3 horas», «Leve», «ACTIVO».
  static const Color darkBadge = Color(0xFF2A3431);

  static const Color darkBadgeBorder = Color(0xFF3C4744);

  static const Color darkBadgeText = Color(0xFFAFD5C5);

  static const Color darkDivider = Color(0xFF293331);

  /// Carril y relleno de las barras de progreso.
  static const Color darkTrack = Color(0xFF333E3A);

  static const Color darkTrackFill = Color(0xFF71AB95);

  /// Fondo de la barra de navegación inferior.
  static const Color darkNav = Color(0xFF1A2220);
}

abstract final class AppText {
  /// Los titulares van en Roboto, la fuente local del proyecto (antes
  /// 'serif', que en Flutter Web dependia de una fuente remota).
  static const String displayFont = 'Roboto';

  /// Saludo de la pantalla principal: «Hola, Karen Lucía».
  ///
  /// Sin color a propósito: el panel la pinta con el token del tema activo.
  static const TextStyle greeting = TextStyle(
    fontFamily: displayFont,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Título de bloque del panel: «Cita Programada», «Estado y Evaluaciones».
  ///
  /// Sin color a propósito, igual que [greeting].
  static const TextStyle panelHeading = TextStyle(
    fontFamily: displayFont,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Titular de pantalla: «Registro de Paciente».
  static const TextStyle display = TextStyle(
    fontFamily: displayFont,
    color: AppColors.brandDark,
    fontSize: 27,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  /// Logotipo «MINDJORA».
  static const TextStyle wordmark = TextStyle(
    fontFamily: displayFont,
    color: AppColors.brandDark,
    fontSize: 29,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    height: 1.1,
  );

  /// Título de bloque dentro de un formulario.
  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.brand,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// Etiqueta de un campo de formulario.
  static const TextStyle label = TextStyle(
    color: Color(0xFF3A4140),
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Detalle entre paréntesis que acompaña a una etiqueta.
  static const TextStyle labelNote = TextStyle(
    color: AppColors.brand,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textSoft,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    color: AppColors.textSoft,
    fontSize: 12,
    height: 1.4,
  );

  /// Texto pulsable subrayado: «Recuperar acceso», «Crear cuenta».
  static const TextStyle link = TextStyle(
    color: AppColors.brandDark,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.brandDark,
  );

  static const TextStyle footer = TextStyle(
    color: AppColors.textSoft,
    fontSize: 11.5,
    height: 1.45,
  );

  /// Aviso legal que comparten el login y el registro.
  static const String privacyNotice =
      'Privacidad y retención de datos: pendiente de verificación humana.';

  /// Aviso del pie del diario, tal como llega en la captura de diseño.
  ///
  /// Es una afirmación legal (secreto profesional y normativa sanitaria), así
  /// que, como el resto de textos legales, necesita verificación humana antes
  /// de publicarse.
  static const String diaryNotice =
      'Registro de bienestar para seguimiento reflexivo personal y clínico. '
      'Confidencialidad bajo secreto profesional según la normativa sanitaria.';

  /// Aviso del pie del perfil, tal como llega en la captura de diseño.
  ///
  /// Describe la segregación de acceso del acompañante (OPER 1 frente a
  /// OPER 2). Es una afirmación legal y de protección de datos, así que, como
  /// el resto de textos legales, necesita verificación humana antes de
  /// publicarse.
  static const String profileNotice =
      'Gestión de perfil y red de apoyo bajo consentimiento informado del '
      'paciente. La vinculación de acompañantes opera bajo segregación OPER 1 '
      'sin acceso a secreto médico ni expediente clínico (OPER 2).';

  /// Motivo del bloqueo de notas, diario y tests para el acompañante.
  ///
  /// Cita la Ley 20.584: pendiente de verificación humana, igual que
  /// [profileNotice].
  static const String lockedNotesNotice =
      'Restringido por secreto médico profesional (Inmutable según Ley '
      '20.584).';

  /// Subtítulo de «Consentimiento informado y políticas de privacidad».
  ///
  /// Cita la Ley 20.584: pendiente de verificación humana.
  static const String consentSubtitle =
      'Protección de datos clínicos según Ley 20.584';

  // --- Detalle de sesión ---------------------------------------------------
  // Los cuatro textos siguientes salen de la captura de diseño y afirman cosas
  // que el negocio tiene que sostener (cifrado, plazo de cancelación,
  // condiciones de pago): pendientes de verificación humana antes de
  // publicarse.

  /// Nota de seguridad de la teleconsulta.
  static const String sessionEncryptionNote =
      'Teleconsulta de 50 min cifrada de grado médico';

  /// Encabezado en negrita de la política de cancelación.
  static const String cancellationPolicyTitle =
      'Política de cancelación sin costo:';

  /// Cuerpo de la política de cancelación (plazo de 12 horas).
  static const String cancellationPolicyBody =
      ' Puedes reprogramar o cancelar libremente hasta 12 horas antes del '
      'inicio de la sesión sin penalización.';

  /// Aviso del pie de la reserva.
  static const String bookingTerms =
      'Términos de reserva y copago: sujeto a confirmación y verificación '
      'administrativa';
}

abstract final class AppRadius {
  static const double card = 12;
  static const double field = 10;
  static const double soft = 9;
}

/// Colores del panel del paciente, resueltos según el modo claro u oscuro.
///
/// El login y el registro leen constantes de [AppColors] porque son vistas de
/// una sola appearance; el panel tiene un interruptor de tema, así que todas sus
/// superficies y textos salen de aquí con `PanelTokens.of(context)`.
class PanelTokens extends ThemeExtension<PanelTokens> {
  const PanelTokens({
    required this.canvas,
    required this.card,
    required this.cardBorder,
    required this.soft,
    required this.softBorder,
    required this.accent,
    required this.accentBorder,
    required this.textStrong,
    required this.textBody,
    required this.textFaint,
    required this.brand,
    required this.brandFill,
    required this.badge,
    required this.badgeBorder,
    required this.badgeText,
    required this.divider,
    required this.track,
    required this.trackFill,
    required this.navBar,
  });

  /// Paleta clara, la misma del directorio de especialistas: lienzo gris
  /// frío, tarjetas blancas con borde neutro y tinta pizarra.
  factory PanelTokens.light() => const PanelTokens(
    canvas: AppColors.canvas,
    card: Colors.white,
    cardBorder: AppColors.border,
    soft: AppColors.softFill,
    softBorder: AppColors.border,
    accent: AppColors.brandSoft,
    accentBorder: Color(0xFFBFD6CE),
    textStrong: AppColors.ink,
    textBody: AppColors.inkSoft,
    textFaint: AppColors.textFaint,
    brand: AppColors.brand,
    brandFill: AppColors.brand,
    badge: AppColors.chipBg,
    badgeBorder: AppColors.border,
    badgeText: AppColors.ink,
    divider: AppColors.divider,
    track: AppColors.border,
    trackFill: Color(0xFF5E8C7A),
    navBar: Colors.white,
  );

  /// Paleta equivalente en oscuro, sobre los verdes de `AppColors.dark*`.
  factory PanelTokens.dark() => const PanelTokens(
    canvas: AppColors.darkCanvas,
    card: AppColors.darkCard,
    cardBorder: AppColors.darkCardBorder,
    soft: AppColors.darkSoft,
    softBorder: AppColors.darkSoftBorder,
    accent: AppColors.darkAccent,
    accentBorder: AppColors.darkAccentBorder,
    textStrong: AppColors.darkTextStrong,
    textBody: AppColors.darkTextBody,
    textFaint: AppColors.darkTextFaint,
    brand: AppColors.darkBrand,
    brandFill: AppColors.darkBrandFill,
    badge: AppColors.darkBadge,
    badgeBorder: AppColors.darkBadgeBorder,
    badgeText: AppColors.darkBadgeText,
    divider: AppColors.darkDivider,
    track: AppColors.darkTrack,
    trackFill: AppColors.darkTrackFill,
    navBar: AppColors.darkNav,
  );

  /// Tokens del tema activo; cae en la paleta clara si no hay ninguno.
  static PanelTokens of(BuildContext context) =>
      Theme.of(context).extension<PanelTokens>() ?? PanelTokens.light();

  /// Fondo de página.
  final Color canvas;

  /// Tarjetas: cita programada, evaluaciones, tareas y acompañante.
  final Color card;
  final Color cardBorder;

  /// Sub-bloques dentro de una tarjeta y botón secundario.
  final Color soft;
  final Color softBorder;

  /// Chip de ánimo seleccionado.
  final Color accent;
  final Color accentBorder;

  /// Titulares y texto de los títulos de tarjeta.
  final Color textStrong;

  /// Descripciones y subtítulos.
  final Color textBody;

  /// Metadatos apagados: duraciones, estados completados.
  final Color textFaint;

  /// Verde de iconos, viñetas y barras.
  final Color brand;

  /// Fondo de los botones principales; el texto va en blanco en ambos modos.
  final Color brandFill;

  /// Píldoras de estado: «En 3 horas», «Leve», «ACTIVO».
  final Color badge;
  final Color badgeBorder;
  final Color badgeText;

  final Color divider;

  /// Carril y relleno de las barras de progreso.
  final Color track;
  final Color trackFill;

  /// Fondo de la barra de navegación inferior.
  final Color navBar;

  @override
  PanelTokens copyWith({
    Color? canvas,
    Color? card,
    Color? cardBorder,
    Color? soft,
    Color? softBorder,
    Color? accent,
    Color? accentBorder,
    Color? textStrong,
    Color? textBody,
    Color? textFaint,
    Color? brand,
    Color? brandFill,
    Color? badge,
    Color? badgeBorder,
    Color? badgeText,
    Color? divider,
    Color? track,
    Color? trackFill,
    Color? navBar,
  }) {
    return PanelTokens(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      soft: soft ?? this.soft,
      softBorder: softBorder ?? this.softBorder,
      accent: accent ?? this.accent,
      accentBorder: accentBorder ?? this.accentBorder,
      textStrong: textStrong ?? this.textStrong,
      textBody: textBody ?? this.textBody,
      textFaint: textFaint ?? this.textFaint,
      brand: brand ?? this.brand,
      brandFill: brandFill ?? this.brandFill,
      badge: badge ?? this.badge,
      badgeBorder: badgeBorder ?? this.badgeBorder,
      badgeText: badgeText ?? this.badgeText,
      divider: divider ?? this.divider,
      track: track ?? this.track,
      trackFill: trackFill ?? this.trackFill,
      navBar: navBar ?? this.navBar,
    );
  }

  @override
  PanelTokens lerp(ThemeExtension<PanelTokens>? other, double t) {
    if (other is! PanelTokens) return this;
    return PanelTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      softBorder: Color.lerp(softBorder, other.softBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBorder: Color.lerp(accentBorder, other.accentBorder, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandFill: Color.lerp(brandFill, other.brandFill, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
      badgeBorder: Color.lerp(badgeBorder, other.badgeBorder, t)!,
      badgeText: Color.lerp(badgeText, other.badgeText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      track: Color.lerp(track, other.track, t)!,
      trackFill: Color.lerp(trackFill, other.trackFill, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
    );
  }
}

/// Temas de la app. El panel del paciente reconstruye el suyo al cambiar de
/// modo, de modo que el interruptor de la cabecera solo tiene que envolver el
/// scaffold en `AppTheme.dark()` o `AppTheme.light()`.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark ? PanelTokens.dark() : PanelTokens.light();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        surface: tokens.canvas,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: tokens.canvas,
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}