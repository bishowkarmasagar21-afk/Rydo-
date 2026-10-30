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
      'booking_next': 'Choose your pickup and destination, calculate a road route, and review the database fare.',
      'driver_next': 'Vehicle approval, online status, ride requests and earnings are connected to verified server functions.',
      'become_driver': 'Become a Driver',
      'driver_application_next': 'Your driver application must be approved before driver tools can be used.',
      'auth_email_sent': 'Registration received. Check your email if confirmation is required.',
      'reset_sent': 'Password reset email requested. Check your inbox.',
      'error_title': 'Something went wrong',
      'pickup': 'Pickup location',
      'destination': 'Destination',
      'search_address': 'Search Nepal addresses',
      'search': 'Search',
      'use_gps': 'Use my location',
      'choose_pickup': 'Choose pickup',
      'choose_destination': 'Choose destination',
      'tap_map': 'Tap map to place the selected pin',
      'calculate_route': 'Calculate road route',
      'route_distance': 'Route distance',
      'estimated_time': 'Estimated time',
      'select_vehicle': 'Choose a vehicle',
      'bike': 'Bike',
      'car': 'Car',
      'tuk_tuk': 'Tuk Tuk',
      'estimated_fare': 'Estimated fare',
      'cash': 'Cash',
      'online_payment': 'Online payment',
      'online_unavailable': 'Online payment is not connected yet. Choose cash; no online payment has been taken.',
      'request_ride': 'Request ride',
      'ride_requested': 'Ride request sent to Rryd.',
      'no_active_ride': 'You do not have an active ride.',
      'active_ride': 'Current ride',
      'ride_history': 'Ride history',
      'refresh': 'Refresh',
      'availability': 'Eligible vehicles reported available',
      'no_availability': 'No eligible vehicles are currently reported available.',
      'fare_not_loaded': 'Current fare rules could not be loaded. A ride cannot be requested until the database fare rules are available.',
      'route_required': 'Choose both locations and calculate a valid road route first.',
      'passenger_role_only': 'The current Rryd database uses one profile role. Passenger booking needs a passenger profile until the backend role system is updated.',
      'map_service_notice': 'Development map service: public map/search/route servers have usage limits and are not approved for production ride-hailing.',
      'map_search_error': 'Address search failed. Try a nearby landmark or place a pin on the map.',
      'route_error': 'Could not calculate a road route. Please choose different locations.',
      'gps_error': 'Could not get your location.',
      'pin_fallback': 'Map pin saved using coordinates. Search for an address to give the driver a clearer location.',
      'no_rides': 'No rides found yet.',
      'ride_id': 'Ride ID',
      'status': 'Status',
      'payment_cash_only': 'Cash payment only',
      'rounding_notice': 'Fare is estimated from the active database rule and rounded to the nearest NPR.',
      'one_active_ride': 'You already have an active ride. Refresh it before requesting another.',
      'map_attribution': 'Map data © OpenStreetMap contributors',
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
      'booking_next': 'पिकअप र गन्तव्य छान्नुहोस्, सडक मार्ग गणना गर्नुहोस् र डाटाबेसको भाडा हेर्नुहोस्।',
      'driver_next': 'सवारी स्वीकृति, अनलाइन स्थिति, राइड अनुरोध र कमाइ प्रमाणित सर्भर फङ्सनसँग जडान गरिनेछ।',
      'become_driver': 'चालक बन्नुहोस्',
      'driver_application_next': 'चालकका सुविधा प्रयोग गर्न पहिले चालक आवेदन स्वीकृत हुनुपर्छ।',
      'auth_email_sent': 'दर्ता अनुरोध प्राप्त भयो। आवश्यक भए इमेल जाँच गर्नुहोस्।',
      'reset_sent': 'पासवर्ड रिसेट इमेल पठाउन अनुरोध गरियो। इनबक्स जाँच गर्नुहोस्।',
      'error_title': 'केही समस्या भयो',
      'pickup': 'पिकअप स्थान',
      'destination': 'गन्तव्य',
      'search_address': 'नेपालका ठेगाना खोज्नुहोस्',
      'search': 'खोज्नुहोस्',
      'use_gps': 'मेरो स्थान प्रयोग गर्नुहोस्',
      'choose_pickup': 'पिकअप छान्नुहोस्',
      'choose_destination': 'गन्तव्य छान्नुहोस्',
      'tap_map': 'छानिएको पिन राख्न नक्सामा थिच्नुहोस्',
      'calculate_route': 'सडक मार्ग गणना गर्नुहोस्',
      'route_distance': 'मार्ग दूरी',
      'estimated_time': 'अनुमानित समय',
      'select_vehicle': 'सवारी छान्नुहोस्',
      'bike': 'मोटरसाइकल',
      'car': 'कार',
      'tuk_tuk': 'टुकटुक',
      'estimated_fare': 'अनुमानित भाडा',
      'cash': 'नगद',
      'online_payment': 'अनलाइन भुक्तानी',
      'online_unavailable': 'अनलाइन भुक्तानी जोडिएको छैन। नगद छान्नुहोस्; कुनै अनलाइन भुक्तानी लिइएको छैन।',
      'request_ride': 'राइड अनुरोध गर्नुहोस्',
      'ride_requested': 'राइड अनुरोध Rryd मा पठाइयो।',
      'no_active_ride': 'तपाईंको सक्रिय राइड छैन।',
      'active_ride': 'हालको राइड',
      'ride_history': 'राइड इतिहास',
      'refresh': 'रिफ्रेस',
      'availability': 'उपलब्ध भनिएका योग्य सवारी',
      'no_availability': 'अहिले कुनै योग्य सवारी उपलब्ध देखिएको छैन।',
      'fare_not_loaded': 'हालको भाडा नियम लोड हुन सकेन। डाटाबेसको भाडा नआएसम्म राइड अनुरोध गर्न मिल्दैन।',
      'route_required': 'पहिले पिकअप र गन्तव्य छानेर मान्य सडक मार्ग गणना गर्नुहोस्।',
      'passenger_role_only': 'हालको Rryd डाटाबेसमा एउटा मात्र प्रोफाइल भूमिका छ। ब्याकएन्ड नबदलिएसम्म यात्रु बुकिङका लागि यात्रु प्रोफाइल चाहिन्छ।',
      'map_service_notice': 'विकास चरणको नक्सा सेवा: सार्वजनिक नक्सा, खोज र मार्ग सर्भरमा प्रयोग सीमा छन्; उत्पादन राइड सेवाका लागि स्वीकृत छैनन्।',
      'map_search_error': 'ठेगाना खोज्न सकिएन। नजिकको चिनिएको स्थान खोज्नुहोस् वा नक्सामा पिन राख्नुहोस्।',
      'route_error': 'सडक मार्ग गणना हुन सकेन। फरक स्थान छान्नुहोस्।',
      'gps_error': 'तपाईंको स्थान पत्ता लगाउन सकिएन।',
      'pin_fallback': 'निर्देशाङ्कबाट नक्सा पिन राखियो। चालकलाई स्पष्ट स्थान दिन ठेगाना खोज्नुहोस्।',
      'no_rides': 'अहिलेसम्म कुनै राइड भेटिएन।',
      'ride_id': 'राइड नम्बर',
      'status': 'स्थिति',
      'payment_cash_only': 'नगद भुक्तानी मात्र',
      'rounding_notice': 'सक्रिय डाटाबेस भाडा नियमअनुसार अनुमान गरिएको भाडा नजिकको रुपैयाँमा राउन्ड गरिन्छ।',
      'one_active_ride': 'तपाईंको एउटा सक्रिय राइड छ। अर्को अनुरोध गर्नुअघि रिफ्रेस गर्नुहोस्।',
      'map_attribution': 'नक्सा डाटा © OpenStreetMap contributors',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']?[key] ?? key;

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
