import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class RrydEmergencyContact {
  const RrydEmergencyContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  factory RrydEmergencyContact.fromMap(Map<String, dynamic> map) =>
      RrydEmergencyContact(
        name: (map['name'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
      );
}

/// Device-local Safety Center. This is not a server-side emergency dispatch
/// or an automatic notification to Rryd. Calls and SMS open the phone's
/// native dialler/messaging app for the user to confirm.
class RrydSafetyCenter {
  RrydSafetyCenter._();

  static Future<void> show(
    BuildContext context, {
    required String appKey,
    String languageCode = 'en',
    String? rideSummary,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RrydSafetySheet(
        appKey: appKey,
        languageCode: languageCode,
        rideSummary: rideSummary,
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  static Future<List<RrydEmergencyContact>> loadContacts(
    String appKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rryd.$appKey.emergency_contacts');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => RrydEmergencyContact.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .where((contact) => contact.name.isNotEmpty && contact.phone.isNotEmpty)
          .take(3)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveContacts(
    String appKey,
    List<RrydEmergencyContact> contacts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      contacts.take(3).map((contact) => contact.toMap()).toList(),
    );
    await prefs.setString('rryd.$appKey.emergency_contacts', encoded);
  }
}

class _RrydSafetySheet extends StatefulWidget {
  const _RrydSafetySheet({
    required this.appKey,
    required this.languageCode,
    this.rideSummary,
    this.locationLabel,
    this.latitude,
    this.longitude,
  });

  final String appKey;
  final String languageCode;
  final String? rideSummary;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;

  @override
  State<_RrydSafetySheet> createState() => _RrydSafetySheetState();
}

class _RrydSafetySheetState extends State<_RrydSafetySheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<RrydEmergencyContact> _contacts = [];
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contacts = await RrydSafetyCenter.loadContacts(widget.appKey);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Could not load emergency contacts: $error';
        _isError = true;
      });
    }
  }

  String _t(String english, String nepali) =>
      widget.languageCode == 'ne' ? nepali : english;

  void _setMessage(String value, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _isError = error;
    });
  }

  String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _addContact() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final phone = _digitsOnly(_phoneController.text.trim());

    if (name.length < 2) {
      _setMessage('Enter the contact person’s name.', error: true);
      return;
    }
    final digits = phone.replaceAll('+', '');
    if (digits.length < 7 || digits.length > 15 ||
        phone.indexOf('+') > 0 ||
        (phone.indexOf('+') == 0 && phone.lastIndexOf('+') != 0)) {
      _setMessage('Enter a valid phone number with country code if needed.',
          error: true);
      return;
    }
    if (_contacts.length >= 3) {
      _setMessage('You can save up to three trusted contacts.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final next = [
        ..._contacts.where((contact) => contact.phone != phone),
        RrydEmergencyContact(name: name, phone: phone),
      ];
      await RrydSafetyCenter.saveContacts(widget.appKey, next);
      if (!mounted) return;
      setState(() {
        _contacts = next.take(3).toList(growable: false);
        _nameController.clear();
        _phoneController.clear();
        _message = 'Trusted contact saved on this device.';
        _isError = false;
      });
    } catch (error) {
      _setMessage('Could not save contact: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeContact(RrydEmergencyContact contact) async {
    final next =
        _contacts.where((item) => item.phone != contact.phone).toList();
    try {
      await RrydSafetyCenter.saveContacts(widget.appKey, next);
      if (mounted) {
        setState(() {
          _contacts = next;
          _message = 'Trusted contact removed.';
          _isError = false;
        });
      }
    } catch (error) {
      _setMessage('Could not remove contact: $error', error: true);
    }
  }

  Future<void> _callNumber(String phone) async {
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!opened) throw StateError('The phone dialler could not be opened.');
    } catch (error) {
      _setMessage('Could not open the phone dialler: $error', error: true);
    }
  }

  String _emergencyMessage() {
    final parts = <String>[
      'I need help. I am using Rryd.',
      if (widget.rideSummary?.isNotEmpty == true)
        'Ride details: ${widget.rideSummary}',
      if (widget.locationLabel?.isNotEmpty == true)
        'Location: ${widget.locationLabel}',
    ];

    final lat = widget.latitude;
    final lon = widget.longitude;
    if (lat != null &&
        lon != null &&
        lat >= 26 &&
        lat <= 31 &&
        lon >= 80 &&
        lon <= 89) {
      final mapUrl = Uri.https('www.openstreetmap.org', '/', {
        'mlat': lat.toStringAsFixed(6),
        'mlon': lon.toStringAsFixed(6),
      });
      parts.add('Map: $mapUrl');
    }
    parts.add('Please contact me.');
    return parts.join('\n');
  }

  Future<void> _textContact(RrydEmergencyContact contact) async {
    try {
      final uri = Uri(
        scheme: 'sms',
        path: contact.phone,
        queryParameters: {'body': _emergencyMessage()},
      );
      final opened = await launchUrl(uri);
      if (!opened) throw StateError('The messaging app could not be opened.');
    } catch (error) {
      _setMessage('Could not open the messaging app: $error', error: true);
    }
  }

  Widget _emergencyButton({
    required String title,
    required String description,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.13),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$description · $number'),
        trailing: IconButton(
          tooltip: 'Call $title',
          onPressed: () => _callNumber(number),
          icon: Icon(Icons.call, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t('Rryd Safety Center', 'Rryd सुरक्षा केन्द्र'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  'For immediate danger, contact emergency services directly. Rryd does not automatically dispatch police or notify its staff from this screen.',
                  'तत्काल जोखिम भए सिधै आपतकालीन सेवामा फोन गर्नुहोस्। यस स्क्रिनबाट Rryd ले प्रहरी बोलाउँदैन वा कर्मचारीलाई स्वतः खबर गर्दैन।',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              _emergencyButton(
                title: _t('Nepal Police', 'नेपाल प्रहरी'),
                description: _t('Police control', 'प्रहरी कन्ट्रोल'),
                number: '100',
                icon: Icons.local_police_outlined,
                color: theme.colorScheme.error,
              ),
              _emergencyButton(
                title: _t('Fire service', 'दमकल सेवा'),
                description: _t('Fire and rescue', 'आगलागी तथा उद्धार'),
                number: '101',
                icon: Icons.local_fire_department_outlined,
                color: Colors.deepOrange,
              ),
              _emergencyButton(
                title: _t('Ambulance', 'एम्बुलेन्स'),
                description: _t('Medical emergency', 'चिकित्सा आपतकाल'),
                number: '102',
                icon: Icons.medical_services_outlined,
                color: Colors.teal,
              ),
              _emergencyButton(
                title: _t('Traffic Police', 'ट्राफिक प्रहरी'),
                description: _t('Traffic emergency', 'ट्राफिक आपतकाल'),
                number: '103',
                icon: Icons.traffic,
                color: Colors.blue,
              ),
              _emergencyButton(
                title: _t('Tourist Police', 'पर्यटक प्रहरी'),
                description: _t('Tourist police helpline', 'पर्यटक प्रहरी हेल्पलाइन'),
                number: '1144',
                icon: Icons.support_agent,
                color: Colors.indigo,
              ),
              Text(
                _t(
                  'Ambulance coverage may vary by location. Use a local ambulance provider if 102 is unavailable.',
                  'एम्बुलेन्स सेवा स्थानअनुसार फरक हुन सक्छ। १०२ उपलब्ध नभए स्थानीय एम्बुलेन्स सेवामा सम्पर्क गर्नुहोस्।',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _t('Trusted contacts', 'विश्वसनीय सम्पर्क'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Save up to three people you trust. Their details stay on this device and are not uploaded to Rryd.', 'तपाईंले विश्वास गर्ने तीन जनासम्मको सम्पर्क सेभ गर्नुहोस्। विवरण यही फोनमा रहन्छ र Rryd मा अपलोड हुँदैन।'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_contacts.isEmpty)
                Text(_t('No trusted contacts saved yet.', 'अहिलेसम्म कुनै विश्वसनीय सम्पर्क सेभ गरिएको छैन।'))
              else
                ..._contacts.map(
                  (contact) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.contact_phone_outlined),
                      title: Text(contact.name),
                      subtitle: Text(contact.phone),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'Send ride details by SMS',
                            onPressed: () => _textContact(contact),
                            icon: const Icon(Icons.sms_outlined),
                          ),
                          IconButton(
                            tooltip: 'Call contact',
                            onPressed: () => _callNumber(contact.phone),
                            icon: const Icon(Icons.call_outlined),
                          ),
                          IconButton(
                            tooltip: 'Remove contact',
                            onPressed: () => _removeContact(contact),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_contacts.length < 3) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _t('Contact name', 'सम्पर्क व्यक्तिको नाम'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _t('Contact phone number', 'सम्पर्क फोन नम्बर'),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addContact,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    _saving
                        ? _t('Saving…', 'सेभ हुँदैछ…')
                        : _t('Save trusted contact', 'विश्वसनीय सम्पर्क सेभ गर्नुहोस्'),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${_t('SMS is opened for your review. Rryd does not send it silently. ', 'SMS तपाईंको जाँचका लागि खुल्छ। Rryd ले चुपचाप सन्देश पठाउँदैन। ')}'
                '${_t('Your mobile operator may charge for SMS or calls.', 'SMS वा कलका लागि मोबाइल अपरेटरले शुल्क लिन सक्छ।')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
