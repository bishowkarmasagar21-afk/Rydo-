import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class RrydStrings {
  const RrydStrings(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<RrydStrings> delegate =
      _RrydStringsDelegate();

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'tagline': 'Move your way.',
      'welcome': 'Welcome to Rryd',
      'journey': 'Your journey starts here.',
      'choose_language': 'Choose your language',
      'english': 'English',
      'nepali': 'Nepali',
      'email': 'Email address',
      'password': 'Password',
      'full_name': 'Full name',
      'phone': 'Phone number',
      'sign_in': 'Sign in',
      'create_account': 'Create account',
      'register': 'Register',
      'already_account': 'Already have an account? Sign in',
      'new_account': 'New to Rryd? Create an account',
      'forgot_password': 'Forgot password?',
      'sign_out': 'Sign out',
      'loading': 'Loading your Rryd account…',
      'configuration_missing': 'Rryd connection is not configured yet.',
      'configuration_help': 'The app needs its Supabase project URL and publishable key before account features can work.',
      'account_ready': 'Your account is connected.',
      'driver_pending': 'Your driver account is awaiting approval.',
      'suspended': 'This account is currently suspended. Contact Rryd support.',
      'wrong_role': 'This account does not yet have access to this Rryd app.',
      'retry': 'Try again',
      'cancel': 'Cancel',
      'save': 'Save',
      'passenger_app': 'Rryd Passenger',
      'driver_app': 'Rryd Driver',
      'booking_next': 'Ride booking, maps, live tracking and payments will be connected after the live database contracts are verified.',
      'driver_next': 'Vehicle selection, online status, ride requests and earnings will be connected to the verified server functions.',
      'become_driver': 'Become a Driver',
      'driver_application_next': 'Your passenger account can be used for driver access after the secure driver-application workflow is connected.',
      'auth_email_sent': 'Registration received. Check your email if confirmation is required.',
      'reset_sent': 'Password reset email requested. Check your inbox.',
      'error_title': 'Something went wrong',
    },
    'ne': {
      'tagline': 'आफ्नै तरिकाले यात्रा गर्नुहोस्।',
      'welcome': 'Rryd मा स्वागत छ',
      'journey': 'तपाईंको यात्रा यहाँबाट सुरु हुन्छ।',
      'choose_language': 'आफ्नो भाषा छान्नुहोस्',
      'english': 'अङ्ग्रेजी',
      'nepali': 'नेपाली',
      'email': 'इमेल ठेगाना',
      'password': 'पासवर्ड',
      'full_name': 'पूरा नाम',
      'phone': 'फोन नम्बर',
      'sign_in': 'साइन इन',
      'create_account': 'खाता बनाउनुहोस्',
      'register': 'दर्ता गर्नुहोस्',
      'already_account': 'पहिले नै खाता छ? साइन इन गर्नुहोस्',
      'new_account': 'Rryd मा नयाँ हुनुहुन्छ? खाता बनाउनुहोस्',
      'forgot_password': 'पासवर्ड बिर्सनुभयो?',
      'sign_out': 'साइन आउट',
      'loading': 'तपाईंको Rryd खाता लोड हुँदैछ…',
      'configuration_missing': 'Rryd जडान अझै कन्फिगर गरिएको छैन।',
      'configuration_help': 'खाता सुविधा चलाउन Supabase project URL र publishable key आवश्यक छ।',
      'account_ready': 'तपाईंको खाता जडान भयो।',
      'driver_pending': 'तपाईंको चालक खाता स्वीकृतिको प्रतीक्षामा छ।',
      'suspended': 'यो खाता हाल निलम्बित छ। Rryd सहयोग केन्द्रमा सम्पर्क गर्नुहोस्।',
      'wrong_role': 'यो खातासँग यस Rryd एपको पहुँच अझै छैन।',
      'retry': 'फेरि प्रयास गर्नुहोस्',
      'cancel': 'रद्द गर्नुहोस्',
      'save': 'सेभ गर्नुहोस्',
      'passenger_app': 'Rryd Passenger',
      'driver_app': 'Rryd Driver',
      'booking_next': 'लाइभ डाटाबेस जाँचपछि राइड बुकिङ, नक्सा, लाइभ ट्र्याकिङ र भुक्तानी जडान गरिनेछ।',
      'driver_next': 'सर्भर फङ्सन जाँचपछि सवारी छनोट, अनलाइन स्थिति, राइड अनुरोध र कमाइ जडान गरिनेछ।',
      'become_driver': 'चालक बन्नुहोस्',
      'driver_application_next': 'सुरक्षित चालक आवेदन प्रक्रिया जडान भएपछि यही खाता चालकका लागि पनि प्रयोग गर्न सकिनेछ।',
      'auth_email_sent': 'दर्ता अनुरोध प्राप्त भयो। आवश्यक भए इमेल जाँच गर्नुहोस्।',
      'reset_sent': 'पासवर्ड रिसेट इमेल पठाउन अनुरोध गरियो। इनबक्स जाँच गर्नुहोस्।',
      'error_title': 'केही समस्या भयो',
    },
  };

  String text(String key) {
    return _values[locale.languageCode]?[key] ??
        _values['en']?[key] ??
        key;
  }

  static RrydStrings of(BuildContext context) {
    final value = Localizations.of<RrydStrings>(context, RrydStrings);
    return value ?? const RrydStrings(Locale('en'));
  }
}

class _RrydStringsDelegate extends LocalizationsDelegate<RrydStrings> {
  const _RrydStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'ne';

  @override
  Future<RrydStrings> load(Locale locale) =>
      SynchronousFuture<RrydStrings>(RrydStrings(locale));

  @override
  bool shouldReload(_RrydStringsDelegate old) => false;
}
