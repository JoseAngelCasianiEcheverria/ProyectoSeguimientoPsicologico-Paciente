import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';

OutlineInputBorder _outline(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );

/// Decoración común de los campos de formulario de las vistas.
InputDecoration appInputDecoration({
  String? hint,
  IconData? icon,
  Widget? suffix,
  EdgeInsets? contentPadding,
}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 14),
  prefixIcon: icon == null
      ? null
      : Padding(
          padding: const EdgeInsets.only(left: 13, right: 9),
          child: Icon(icon, size: 20, color: const Color(0xFF8A9291)),
        ),
  suffixIcon: suffix,
  filled: true,
  fillColor: Colors.white,
  contentPadding:
      contentPadding ??
      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  border: _outline(AppColors.border),
  enabledBorder: _outline(AppColors.border),
  focusedBorder: _outline(AppColors.brand, 1.3),
  errorBorder: _outline(AppColors.error),
  focusedErrorBorder: _outline(AppColors.error, 1.3),
  errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
);

/// Tarjeta blanca con borde: bloque base de los formularios.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 14));
      spaced.add(children[i]);
    }
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced,
      ),
    );
  }
}

/// Título de bloque con icono y línea divisoria debajo.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.brand, size: 20),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: AppText.sectionTitle)),
          ],
        ),
        const SizedBox(height: 13),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Campo de formulario con etiqueta, detalle opcional y acción opcional.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.note,
    this.labelAction,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.capitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
  });

  final String label;

  /// Detalle que se muestra junto a la etiqueta, entre paréntesis.
  final String? note;

  /// Enlace a la derecha de la etiqueta, por ejemplo «¿Olvidaste tu
  /// contraseña?».
  final Widget? labelAction;

  final String? hint;
  final IconData? icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization capitalization;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabelRow(),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: capitalization,
          obscureText: obscureText,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          textInputAction: textInputAction,
          decoration: appInputDecoration(
            hint: hint,
            icon: icon,
            suffix: suffix,
          ),
        ),
      ],
    );
  }

  /// Etiqueta a la izquierda y, si la hay, acción anclada a la derecha.
  ///
  /// Con acción, las dos van en un `Stack` en vez de en un `Row`: en un `Row`
  /// el enlace tendría que ser flexible para no desbordar, y dos hijos
  /// flexibles se reparten el ancho a mitades, así que siempre se recortaría un
  /// poco. En el `Stack` cada uno conserva su ancho natural; si en una pantalla
  /// estrecha no caben los dos, el enlace baja de línea en vez de salirse de la
  /// tarjeta. El hueco reservado a la derecha evita que la etiqueta llegue
  /// debajo del enlace.
  Widget _buildLabelRow() {
    final title = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.label,
      ),
    );
    final left = Row(
      children: [
        title,
        if (note != null) Text(note!, style: AppText.labelNote),
      ],
    );

    if (labelAction == null) return left;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(right: note != null ? 0 : 110),
          child: left,
        ),
        Positioned(right: 0, top: 0, child: labelAction!),
      ],
    );
  }
}

/// Botón principal, con el icono a la derecha como en las vistas.
///
/// `backgroundColor`/`foregroundColor` existen para las vistas con interruptor
/// de tema (el panel), que pasan los tokens en vez de los verdes fijos.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.minHeight = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? Colors.white;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.brand,
        foregroundColor: foreground,
        minimumSize: Size.fromHeight(minHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 19)],
        ],
      ),
    );
  }
}

/// Botón secundario: mismo alto que [PrimaryButton] sobre el sub-bloque crema,
/// por ejemplo «Detalles de la cita» o «Realizar →».
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.minWidth = double.infinity,
    this.minHeight = 50,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.fontSize = 14,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  /// `double.infinity` lo estira a todo el ancho disponible; ponle un valor
  /// concreto cuando el botón vive dentro de una fila con ancho limitado.
  final double minWidth;
  final double minHeight;
  final EdgeInsets padding;
  final double fontSize;

  /// Flecha o icono a la derecha del texto, separado del resto.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? AppColors.brandDark;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.creamSoft,
        foregroundColor: foreground,
        side: BorderSide(color: borderColor ?? AppColors.creamBorder),
        minimumSize: Size(minWidth, minHeight),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 9)],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// Botón cuadrado con borde de las cabeceras del panel: campana, avatar y
/// el interruptor de tema junto al saludo.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.badge = false,
    this.badgeColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  /// Punto de «tiene notificaciones nuevas».
  final bool badge;

  /// Tinta del punto de [badge]; por defecto el verde de la marca.
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 19),
          if (badge)
            Positioned(
              right: -3,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor ?? AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: backgroundColor ?? Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.white,
        foregroundColor: foregroundColor ?? AppColors.brandDark,
        side: BorderSide(color: borderColor ?? AppColors.border),
        fixedSize: Size.square(size),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    );
  }
}

/// Botón de volver, cuadrado y con borde.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Volver atrás',
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back_rounded, size: 20),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandDark,
        side: const BorderSide(color: AppColors.border),
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    );
  }
}

/// Pill de progreso: «Paso 1 de 2: Datos de Cuenta».
class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de privacidad del pie de las vistas.
///
/// `dashed` cambia el marco por el punteado del diseño, que Material no tiene
/// como `Border`, y obliga a dejar de pintar el borde normal para que no se
/// vean los dos.
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({
    super.key,
    this.text,
    this.background,
    this.borderColor,
    this.centered,
    this.dashed = false,
    this.icon = Icons.info_outline_rounded,
  });

  final String? text;
  final Color? background;
  final Color? borderColor;
  final bool? centered;
  final bool dashed;

  /// Icono de la izquierda; el aviso del login usa el de exclamación.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fill = background ?? AppColors.noticeBg;
    final stroke = borderColor ?? AppColors.border;
    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: dashed
          ? null
          : BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: stroke),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: AppColors.textSoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text ?? AppText.privacyNotice,
              textAlign: centered == true ? TextAlign.center : TextAlign.start,
              style: AppText.footer,
            ),
          ),
        ],
      ),
    );
    if (!dashed) return content;
    return CustomPaint(
      painter: DashedBorderPainter(fill: fill, stroke: stroke),
      child: content,
    );
  }
}

/// Marco punteado con relleno, dibujado a mano.
///
/// Lo usan el aviso del login y el de encuadre del directorio de
/// especialistas. Se pinta por debajo del hijo, así que el hijo debe dejar
/// transparente su propio relleno.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  /// Largo de cada tramo y del hueco que lo separa.
  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      const Radius.circular(AppRadius.field),
    );
    canvas.drawRRect(frame, Paint()..color = fill);

    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(frame);
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = start + _dash < metric.length
            ? start + _dash
            : metric.length;
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}

/// Logo de la marca, recortado y centrado sobre el cerebro.
///
/// En `logo.jpg` el cerebro es pequeño y queda en la mitad superior del
/// cuadrado; con un simple `BoxFit.cover` se ve diminuto y descentrado. Aquí se
/// muestra solo la zona del dibujo (≈ 55 % del lado), centrada en él.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size, this.radius = 10});

  final double size;
  final double radius;

  /// Fracción del lado de la imagen que se muestra.
  static const double _visible = 0.55;

  /// Punto de la imagen que queda en el centro del recorte (el cerebro).
  static const Alignment _focus = Alignment(0.02, -0.455);

  @override
  Widget build(BuildContext context) {
    final full = size / _visible;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          alignment: _focus,
          minWidth: full,
          maxWidth: full,
          minHeight: full,
          maxHeight: full,
          child: Image.asset(
            'assets/images/logo.jpg',
            width: full,
            height: full,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// Interruptor con los colores de la marca.
Widget appSwitch({required bool value, required ValueChanged<bool> onChanged}) {
  return Switch(
    value: value,
    onChanged: onChanged,
    activeThumbColor: Colors.white,
    activeTrackColor: AppColors.brand,
    thumbIcon: const WidgetStatePropertyAll<Icon?>(null),
    trackOutlineColor: const WidgetStatePropertyAll<Color?>(Color(0xFFCFD6D4)),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

// --- Piezas del panel del paciente y del directorio -----------------------

/// Centra el contenido en pantallas amplias y conserva el ancho móvil.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Título serif de bloque con su nota de la derecha («Septiembre 2026»).
///
/// Vive aquí porque lo comparten el panel del paciente y el directorio de
/// especialistas, que no usan la misma paleta: el color llega por parámetro en
/// vez de leerse de [PanelTokens].
class PanelSectionHeading extends StatelessWidget {
  const PanelSectionHeading({
    super.key,
    required this.title,
    required this.color,
    this.trailing,
    this.fontSize = 16,
  });

  final String title;
  final Color color;

  /// Nota o contador de la derecha: «Septiembre 2026», «1 de 2 listas».
  final Widget? trailing;

  /// El panel sube el título a 19; el directorio de especialistas lo deja en 16.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.panelHeading.copyWith(
              color: color,
              fontSize: fontSize,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Aviso de que todavía no hay datos que mostrar.
///
/// Lo usa el portal del paciente en modo real: cuando la consulta no devuelve
/// nada, la pantalla avisa en vez de pintar un dato inventado. El [texto] es lo
/// que se comprueba en las pruebas, así que no se acorta ni se parafrasea.
class AvisoVacio extends StatelessWidget {
  const AvisoVacio({super.key, required this.texto, this.t});

  /// Mensaje que ve la persona, p. ej. «Aún no tienes citas programadas.»
  final String texto;

  /// Tokens del panel. Si se omiten se leen del contexto.
  final PanelTokens? t;

  @override
  Widget build(BuildContext context) {
    final tokens = t ?? PanelTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.soft,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: tokens.softBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: tokens.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: tokens.textFaint, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra inferior fija: Inicio, Agenda, Diario y Perfil.
///
/// [selectedIndex] marca la pestaña activa (el panel marca Inicio y el
/// directorio Agenda). [onTabSelected] deja que cada pantalla abra su
/// sección; si se omite, los toques no hacen nada.
class PanelBottomNav extends StatelessWidget {
  const PanelBottomNav({
    super.key,
    required this.selectedIndex,
    required this.backgroundColor,
    required this.borderColor,
    required this.selectedColor,
    required this.idleColor,
    this.onTabSelected,
  });

  final int selectedIndex;
  final Color backgroundColor;
  final Color borderColor;

  /// Color de la pestaña activa: icono y etiqueta.
  final Color selectedColor;

  /// Color de las pestañas inactivas.
  final Color idleColor;
  final ValueChanged<int>? onTabSelected;

  static const _tabs = <({String label, IconData icon, IconData active})>[
    (label: 'Inicio', icon: Icons.home_outlined, active: Icons.home_rounded),
    (
      label: 'Agenda',
      icon: Icons.calendar_today_outlined,
      active: Icons.calendar_today_rounded,
    ),
    (
      label: 'Diario',
      icon: Icons.menu_book_outlined,
      active: Icons.menu_book_rounded,
    ),
    (
      label: 'Perfil',
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ResponsiveContent(
            maxWidth: 960,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavTab(
                      label: _tabs[i].label,
                      icon: i == selectedIndex
                          ? _tabs[i].active
                          : _tabs[i].icon,
                      selected: i == selectedIndex,
                      selectedColor: selectedColor,
                      idleColor: idleColor,
                      onTap: onTabSelected == null
                          ? null
                          : () => onTabSelected!(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.idleColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color idleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : idleColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.body.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Dra. Yani Casiani» → «YC», para la foto de respaldo.
String inicialesDe(String nombre) {
  final partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '—';
  final sans = partes.map(
    (p) => p.replaceFirst(RegExp(r'^(Dra?|Dr|Psic\.)[.\s]*'), ''),
  );
  final utiles = sans.where((p) => p.isNotEmpty).toList();
  if (utiles.isEmpty) return '—';
  if (utiles.length == 1) return utiles.first.substring(0, 1).toUpperCase();
  return '${utiles[0][0]}${utiles[1][0]}'.toUpperCase();
}

/// Foto de perfil del profesional. Si no hay foto (o falla la carga) se ven
/// las iniciales, como en el resto del portal.
class FotoPerfil extends StatelessWidget {
  const FotoPerfil({
    super.key,
    required this.iniciales,
    this.url,
    this.size = 48,
    this.radius = 10,
  });

  final String iniciales;
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fondo = BoxDecoration(
      color: AppColors.brandSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
    );
    final texto = Center(
      child: Text(
        iniciales,
        style: AppText.wordmark.copyWith(
          color: AppColors.brandDark,
          fontSize: size * 0.33,
          letterSpacing: 0.5,
        ),
      ),
    );
    final urlFoto = url;
    if (urlFoto == null || urlFoto.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: fondo,
        child: texto,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        urlFoto,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: fondo,
          child: texto,
        ),
      ),
    );
  }
}
