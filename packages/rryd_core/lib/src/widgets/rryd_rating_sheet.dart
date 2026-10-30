import 'package:flutter/material.dart';

import '../theme/rryd_theme.dart';

class RrydRatingSheet {
  RrydRatingSheet._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String languageCode,
    required Future<void> Function(int rating, String feedback) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RrydRatingSheetBody(
        title: title,
        languageCode: languageCode,
        onSubmit: onSubmit,
      ),
    );
  }
}

class _RrydRatingSheetBody extends StatefulWidget {
  const _RrydRatingSheetBody({
    required this.title,
    required this.languageCode,
    required this.onSubmit,
  });

  final String title;
  final String languageCode;
  final Future<void> Function(int rating, String feedback) onSubmit;

  @override
  State<_RrydRatingSheetBody> createState() => _RrydRatingSheetBodyState();
}

class _RrydRatingSheetBodyState extends State<_RrydRatingSheetBody> {
  final _feedback = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;

  bool get _nepali => widget.languageCode == 'ne';

  String _t(String en, String ne) => _nepali ? ne : en;

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_feedback.text.trim().length > 1000) {
      setState(() => _error = _t(
            'Feedback must be at most 1000 characters.',
            'प्रतिक्रिया बढीमा १००० अक्षरको हुनुपर्छ।',
          ));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _feedback.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t('How was your trip?', 'तपाईंको यात्रा कस्तो भयो?'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Center(
                child: Wrap(
                  spacing: 8,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _rating = index + 1),
                      iconSize: 36,
                      color: index < _rating
                          ? RrydTheme.orange
                          : theme.colorScheme.onSurfaceVariant,
                      icon: Icon(
                        index < _rating ? Icons.star : Icons.star_outline,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _t('$_rating out of 5', '५ मध्ये $_rating'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _feedback,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: _t('Optional feedback', 'ऐच्छिक प्रतिक्रिया'),
                  hintText: _t(
                    'Share a few details about your experience',
                    'आफ्नो अनुभवबारे केही कुरा लेख्नुहोस्',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_t('Submit rating', 'रेटिङ पठाउनुहोस्')),
              ),
              Text(
                _t(
                  'One rating can be submitted for each completed ride. Ratings cannot be edited after submission.',
                  'प्रत्येक सम्पन्न राइडमा एक पटक मात्र रेटिङ दिन सकिन्छ। पठाएपछि सम्पादन गर्न मिल्दैन।',
                ),
                textAlign: TextAlign.center,
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
