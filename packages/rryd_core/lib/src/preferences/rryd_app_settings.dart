import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/rryd_language.dart';

class RrydAppSettings extends ChangeNotifier {
  RrydAppSettings._({
    required SharedPreferences preferences,
    required String appKey,
    required RrydLanguage language,
    required bool useLightTheme,
  })  : _preferences = preferences,
        _appKey = appKey,
        _language = language,
        _useLightTheme = useLightTheme;

  final SharedPreferences _preferences;
  final String _appKey;
  RrydLanguage _language;
  bool _useLightTheme;

  RrydLanguage get language => _language;
  bool get useLightTheme => _useLightTheme;

  static Future<RrydAppSettings> load({required String appKey}) async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString('rryd.' + appKey + '.language');
    final themeValue = preferences.getBool('rryd.' + appKey + '.light_theme');

    return RrydAppSettings._(
      preferences: preferences,
      appKey: appKey,
      language: RrydLanguage.fromCode(languageCode),
      useLightTheme: themeValue ?? false,
    );
  }

  Future<void> setLanguage(RrydLanguage value) async {
    if (_language == value) return;
    _language = value;
    await _preferences.setString(
      'rryd.' + _appKey + '.language',
      value.code,
    );
    notifyListeners();
  }

  Future<void> setLightTheme(bool value) async {
    if (_useLightTheme == value) return;
    _useLightTheme = value;
    await _preferences.setBool(
      'rryd.' + _appKey + '.light_theme',
      value,
    );
    notifyListeners();
  }
}
