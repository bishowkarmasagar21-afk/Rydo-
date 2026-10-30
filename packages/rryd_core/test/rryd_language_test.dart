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

  test('fare estimates round to nearest NPR with half rounding up', () {
    final rule = RrydFareRule(
      vehicleType: 'bike',
      baseFare: 20,
      perKmFare: 15,
      commissionPercent: 15,
    );
    expect(rule.estimate((57.2 - 20) / 15), 57);
    expect(rule.estimate((57.5 - 20) / 15), 58);
  });

  test('Nepal location validation rejects points outside Nepal', () {
    expect(
      const RrydLocationPoint(
        label: 'Kathmandu',
        latitude: 27.7172,
        longitude: 85.3240,
      ).isInsideNepal,
      isTrue,
    );
    expect(
      const RrydLocationPoint(
        label: 'Outside Nepal',
        latitude: 25.0,
        longitude: 85.0,
      ).isInsideNepal,
      isFalse,
    );
  });

  test('localized strings contain English and Nepali labels', () {
    expect(RrydStrings(const Locale('en')).text('sign_in'), 'Sign in');
    expect(RrydStrings(const Locale('ne')).text('sign_in'), 'साइन इन');
  });
}
