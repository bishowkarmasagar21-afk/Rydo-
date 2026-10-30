import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rryd_core/rryd_core.dart';

void main() {
  test('language codes restore English and Nepali settings', () {
    expect(RrydLanguage.fromCode('en'), RrydLanguage.english);
    expect(RrydLanguage.fromCode('ne'), RrydLanguage.nepali);
    expect(RrydLanguage.fromCode('unknown'), RrydLanguage.english);
  });

  test('device locale selects Nepali when phone language is Nepali', () {
    expect(
      RrydLanguage.fromDeviceLocale(const Locale('ne')),
      RrydLanguage.nepali,
    );
    expect(
      RrydLanguage.fromDeviceLocale(const Locale('en')),
      RrydLanguage.english,
    );
  });

  test('localized strings contain English and Nepali labels', () {
    expect(RrydStrings(const Locale('en')).text('sign_in'), 'Sign in');
    expect(RrydStrings(const Locale('ne')).text('sign_in'), 'साइन इन');
  });
}
