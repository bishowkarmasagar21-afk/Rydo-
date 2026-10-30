import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rryd_core/rryd_core.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key, required this.settings});

  final RrydAppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Rryd Driver',
          debugShowCheckedModeBanner: false,
          locale: settings.language.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('ne'),
          ],
          localizationsDelegates: const [
            RrydStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: settings.useLightTheme ? RrydTheme.light() : RrydTheme.dark(),
          home: RrydAuthGate(
            appRole: 'driver',
            appTitle: 'Rryd Driver',
            appScheme: 'com.rryd.driver',
            settings: settings,
            allowPassengerRegistration: false,
            homeBuilder: (context, profile) => DriverHomePage(
              profile: profile,
              settings: settings,
            ),
          ),
        );
      },
    );
  }
}

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({
    super.key,
    required this.profile,
    required this.settings,
  });

  final RrydProfile profile;
  final RrydAppSettings settings;

  @override
  Widget build(BuildContext context) {
    final strings = RrydStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rryd Driver'),
        actions: [
          PopupMenuButton<RrydLanguage>(
            tooltip: strings.text('choose_language'),
            icon: const Icon(Icons.translate),
            onSelected: settings.setLanguage,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: RrydLanguage.english,
                child: Text(strings.text('english')),
              ),
              PopupMenuItem(
                value: RrydLanguage.nepali,
                child: Text(strings.text('nepali')),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => settings.setLightTheme(!settings.useLightTheme),
            icon: Icon(
              settings.useLightTheme
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: strings.text('sign_out'),
            onPressed: () => RrydAuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              strings.text('welcome'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.fullName.isEmpty ? 'Rryd Driver' : profile.fullName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.directions_car_filled_rounded,
                      color: RrydTheme.orange,
                      size: 34,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.text('account_ready'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(strings.text('driver_next')),
                    const SizedBox(height: 16),
                    Text(
                      'Going online is not enabled in this foundation build. The vehicle-selection and one-active-ride rules must be enforced by Supabase before accepting requests.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Role', value: profile.role),
                    _InfoRow(
                      label: 'Verification',
                      value: profile.isVerified ? 'Approved' : 'Pending',
                    ),
                    _InfoRow(
                      label: 'Account status',
                      value: profile.isSuspended ? 'Suspended' : 'Active',
                    ),
                    _InfoRow(
                      label: 'Current online status',
                      value: profile.isOnline ? 'Online' : 'Offline',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
