import 'package:flutter/widgets.dart';

enum RrydLanguage {
  english('en'),
  nepali('ne');

  const RrydLanguage(this.code);

  final String code;

  Locale get locale => Locale(code);

  static RrydLanguage fromCode(String? value) {
    return value == 'ne' ? RrydLanguage.nepali : RrydLanguage.english;
  }

  static RrydLanguage fromDeviceLocale(Locale locale) {
    return locale.languageCode == 'ne'
        ? RrydLanguage.nepali
        : RrydLanguage.english;
  }
}
