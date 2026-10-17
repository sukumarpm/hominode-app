import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Localized Text Widget
/// Automatically rebuilds when language changes
class LocalizedText extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? params;

  const LocalizedText(
    this.translationKey, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Text(
      translationKey.tr(namedArgs: params),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Localized Button Text Widget
class LocalizedButton extends StatelessWidget {
  final String translationKey;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  final Map<String, String>? params;

  const LocalizedButton(
    this.translationKey, {
    super.key,
    required this.onPressed,
    this.style,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(translationKey.tr(namedArgs: params)),
    );
  }
}

/// Localized Text Button Widget
class LocalizedTextButton extends StatelessWidget {
  final String translationKey;
  final VoidCallback onPressed;
  final TextStyle? style;
  final Map<String, String>? params;

  const LocalizedTextButton(
    this.translationKey, {
    super.key,
    required this.onPressed,
    this.style,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return TextButton(
      onPressed: onPressed,
      child: Text(translationKey.tr(namedArgs: params), style: style),
    );
  }
}

/// Localized Outlined Button Widget
class LocalizedOutlinedButton extends StatelessWidget {
  final String translationKey;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  final Map<String, String>? params;

  const LocalizedOutlinedButton(
    this.translationKey, {
    super.key,
    required this.onPressed,
    this.style,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: Text(translationKey.tr(namedArgs: params)),
    );
  }
}

/// Localized App Bar Title
class LocalizedAppBarTitle extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final Map<String, String>? params;

  const LocalizedAppBarTitle(
    this.translationKey, {
    super.key,
    this.style,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Text(
      translationKey.tr(namedArgs: params),
      style:
          style ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    );
  }
}

/// Localized Tooltip
class LocalizedTooltip extends StatelessWidget {
  final String translationKey;
  final Widget child;
  final Map<String, String>? params;

  const LocalizedTooltip(
    this.translationKey, {
    super.key,
    required this.child,
    this.params,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Tooltip(
      message: translationKey.tr(namedArgs: params),
      child: child,
    );
  }
}
