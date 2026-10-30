import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/supabase_bootstrap.dart';
import '../localization/rryd_language.dart';
import '../localization/rryd_strings.dart';
import '../models/rryd_profile.dart';
import '../models/rryd_profile_repository.dart';
import '../preferences/rryd_app_settings.dart';
import '../theme/rryd_theme.dart';
import 'rryd_auth_service.dart';

typedef RrydAuthenticatedBuilder = Widget Function(
  BuildContext context,
  RrydProfile profile,
);

class RrydAuthGate extends StatefulWidget {
  const RrydAuthGate({
    super.key,
    required this.appRole,
    required this.appTitle,
    required this.appScheme,
    required this.settings,
    required this.homeBuilder,
    this.allowPassengerRegistration = false,
    this.allowDriverRegistration = false,
  });

  final String appRole;
  final String appTitle;
  final String appScheme;
  final RrydAppSettings settings;
  final RrydAuthenticatedBuilder homeBuilder;
  final bool allowPassengerRegistration;
  final bool allowDriverRegistration;

  @override
  State<RrydAuthGate> createState() => _RrydAuthGateState();
}

class _RrydAuthGateState extends State<RrydAuthGate> {
  final RrydAuthService _auth = RrydAuthService();
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  RrydProfile? _profile;
  Object? _profileError;
  bool _loading = true;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();

    if (!SupabaseBootstrap.isInitialized) {
      _loading = false;
      return;
    }

    _user = _auth.currentUser;
    if (_user == null) {
      _loading = false;
    } else {
      _loadProfile(_user!.id);
    }

    _authSubscription = _auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        if (!mounted) return;
        setState(() => _passwordRecovery = true);
        return;
      }
      final nextUser = state.session?.user;
      if (nextUser?.id == _user?.id) return;

      if (!mounted) return;
      setState(() {
        _user = nextUser;
        _profile = null;
        _profileError = null;
        _loading = nextUser != null;
      });

      if (nextUser != null) {
        _loadProfile(nextUser.id);
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _profileError = null;
    });

    try {
      final profile = await RrydProfileRepository().load(userId);
      if (!mounted || _user?.id != userId) return;
      setState(() {
        _profile = profile;
        _profileError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _user?.id != userId) return;
      setState(() {
        _profileError = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = RrydStrings.of(context);

    if (!SupabaseBootstrap.isInitialized) {
      return _RrydNoticeScreen(
        title: strings.text('configuration_missing'),
        message: strings.text('configuration_help'),
        icon: Icons.cloud_off_outlined,
      );
    }

    if (_passwordRecovery && _user != null) {
      return RrydPasswordRecoveryScreen(
        onCompleted: () async {
          if (!mounted) return;
          setState(() => _passwordRecovery = false);
          await _loadProfile(_user!.id);
        },
      );
    }

    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(strings.text('loading')),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return RrydEmailAuthScreen(
        appTitle: widget.appTitle,
        appScheme: widget.appScheme,
        settings: widget.settings,
        allowPassengerRegistration: widget.allowPassengerRegistration,
        allowDriverRegistration: widget.allowDriverRegistration,
      );
    }

    if (_profileError != null) {
      return _RrydNoticeScreen(
        title: strings.text('error_title'),
        message: _profileError.toString(),
        icon: Icons.error_outline,
        primaryLabel: strings.text('retry'),
        onPrimary: () => _loadProfile(_user!.id),
        secondaryLabel: strings.text('sign_out'),
        onSecondary: _auth.signOut,
      );
    }

    final profile = _profile;
    if (profile == null) {
      return _RrydNoticeScreen(
        title: strings.text('error_title'),
        message: 'The signed-in account profile could not be loaded.',
        icon: Icons.error_outline,
        primaryLabel: strings.text('retry'),
        onPrimary: () => _loadProfile(_user!.id),
      );
    }

    if (profile.isSuspended) {
      return _RrydNoticeScreen(
        title: strings.text('suspended'),
        message: 'Account access is blocked by the Rryd profile status.',
        icon: Icons.lock_outline,
        secondaryLabel: strings.text('sign_out'),
        onSecondary: _auth.signOut,
      );
    }

    if (widget.appRole == 'driver') {
      if (profile.role != 'driver') {
        return _RrydNoticeScreen(
          title: strings.text('wrong_role'),
          message: strings.text('driver_application_next'),
          icon: Icons.person_search_outlined,
          secondaryLabel: strings.text('sign_out'),
          onSecondary: _auth.signOut,
        );
      }

    } else {
      // The current database stores exactly one profile role. A driver
      // profile is therefore not eligible for the Passenger app yet.
      // Do not relax this client check until the backend role/eligibility
      // migration and request_ride authorization have both been deployed.
      if (profile.role != 'passenger') {
        return _RrydNoticeScreen(
          title: strings.text('wrong_role'),
          message: 'The profile role is not eligible for the Passenger app.',
          icon: Icons.lock_outline,
          secondaryLabel: strings.text('sign_out'),
          onSecondary: _auth.signOut,
        );
      }
    }

    return widget.homeBuilder(context, profile);
  }
}

class RrydPasswordRecoveryScreen extends StatefulWidget {
  const RrydPasswordRecoveryScreen({
    super.key,
    required this.onCompleted,
  });

  final Future<void> Function() onCompleted;

  @override
  State<RrydPasswordRecoveryScreen> createState() =>
      _RrydPasswordRecoveryScreenState();
}

class _RrydPasswordRecoveryScreenState
    extends State<RrydPasswordRecoveryScreen> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (password != _confirmPassword.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseBootstrap.client.auth.updateUser(
        UserAttributes(password: password),
      );
      await widget.onCompleted();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rryd · New password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        size: 46,
                        color: RrydTheme.orange,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Set a new password',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a new password for your Rryd account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _showPassword = !_showPassword,
                            ),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: !_showPassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save new password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RrydEmailAuthScreen extends StatefulWidget {
  const RrydEmailAuthScreen({
    super.key,
    required this.appTitle,
    required this.appScheme,
    required this.settings,
    this.allowPassengerRegistration = false,
    this.allowDriverRegistration = false,
  });

  final String appTitle;
  final String appScheme;
  final RrydAppSettings settings;
  final bool allowPassengerRegistration;
  final bool allowDriverRegistration;

  @override
  State<RrydEmailAuthScreen> createState() => _RrydEmailAuthScreenState();
}

class _RrydEmailAuthScreenState extends State<RrydEmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  final RrydAuthService _auth = RrydAuthService();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (_register) {
        final response = widget.allowDriverRegistration
            ? await _auth.registerDriver(
                fullName: _name.text,
                phone: _phone.text,
                email: _email.text,
                password: _password.text,
              )
            : await _auth.registerPassenger(
                fullName: _name.text,
                phone: _phone.text,
                email: _email.text,
                password: _password.text,
              );

        if (response.session == null) {
          _setMessage(
            RrydStrings.of(context).text('auth_email_sent'),
            isError: false,
          );
        }
      } else {
        await _auth.signIn(
          email: _email.text,
          password: _password.text,
        );
      }
    } catch (error) {
      _setMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setMessage('Enter your account email address first.', isError: true);
      return;
    }

    try {
      await _auth.requestPasswordReset(
        email: email,
        appScheme: widget.appScheme,
      );
      _setMessage(
        RrydStrings.of(context).text('reset_sent'),
        isError: false,
      );
    } catch (error) {
      _setMessage(error.toString(), isError: true);
    }
  }

  void _setMessage(String value, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = RrydStrings.of(context);
    final theme = Theme.of(context);
    const orange = RrydTheme.orange;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appTitle),
        actions: [
          PopupMenuButton<RrydLanguage>(
            tooltip: strings.text('choose_language'),
            icon: const Icon(Icons.translate),
            onSelected: widget.settings.setLanguage,
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
            onPressed: () => widget.settings.setLightTheme(
              !widget.settings.useLightTheme,
            ),
            icon: Icon(
              widget.settings.useLightTheme
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: orange.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              color: orange,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'Rryd',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 38,
                              letterSpacing: 2,
                              color: orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(child: Text(strings.text('tagline'))),
                        const SizedBox(height: 26),
                        Text(
                          _register
                              ? strings.text('create_account')
                              : strings.text('welcome'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: strings.text('full_name'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().length < 2)
                                    ? 'Enter your full name.'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: strings.text('phone'),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().length < 7)
                                    ? 'Enter a valid contact phone number.'
                                    : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: strings.text('email'),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!email.contains('@') || email.length < 5) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: strings.text('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        if (!_register) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _forgotPassword,
                              child: Text(strings.text('forgot_password')),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 18),
                        if (_message != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_messageIsError
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _messageIsError
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _register
                                      ? strings.text('create_account')
                                      : strings.text('sign_in'),
                                ),
                        ),
                        if (widget.allowPassengerRegistration ||
                            widget.allowDriverRegistration) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _register = !_register;
                                      _message = null;
                                    }),
                            child: Text(
                              _register
                                  ? strings.text('already_account')
                                  : strings.text('new_account'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          widget.allowDriverRegistration
                              ? 'Your driver profile and vehicle(s) must be reviewed by Rryd Admin before you can receive rides.'
                              : 'Phone number is saved as profile contact. SMS OTP is not sent during this initial email/password setup.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RrydNoticeScreen extends StatelessWidget {
  const _RrydNoticeScreen({
    required this.title,
    required this.message,
    required this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 46, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center),
                      if (primaryLabel != null && onPrimary != null) ...[
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: onPrimary,
                          child: Text(primaryLabel!),
                        ),
                      ],
                      if (secondaryLabel != null && onSecondary != null)
                        TextButton(
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
