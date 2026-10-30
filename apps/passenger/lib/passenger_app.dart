import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rryd_core/rryd_core.dart';

class PassengerApp extends StatelessWidget {
  const PassengerApp({super.key, required this.settings});

  final RrydAppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Rryd Passenger',
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
            appRole: 'passenger',
            appTitle: 'Rryd Passenger',
            appScheme: 'com.rryd.passenger',
            settings: settings,
            allowPassengerRegistration: true,
            homeBuilder: (context, profile) => PassengerHomePage(
              profile: profile,
              settings: settings,
            ),
          ),
        );
      },
    );
  }
}

class PassengerHomePage extends StatelessWidget {
  const PassengerHomePage({
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
    final isDriverProfile = profile.role == 'driver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rryd'),
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
              profile.fullName.isEmpty ? 'Rryd Passenger' : profile.fullName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      child: Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.phone.isEmpty
                                ? profile.role.toUpperCase()
                                : profile.phone,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            profile.role == 'driver'
                                ? 'Passenger access with an existing driver account'
                                : 'Passenger account',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_user_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          color: RrydTheme.orange,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.text('journey'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(strings.text('booking_next')),
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(value: 0.12),
                    const SizedBox(height: 8),
                    Text(
                      'Booking is not enabled in this foundation build. No ride request or payment is sent from this screen.',
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
                      strings.text('become_driver'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDriverProfile
                          ? strings.text('driver_application_next')
                          : strings.text('driver_application_next'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The application action will be enabled after the existing Supabase role and driver-approval workflow is verified.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
