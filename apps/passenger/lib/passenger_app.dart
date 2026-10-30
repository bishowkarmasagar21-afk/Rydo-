import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:rryd_core/rryd_core.dart';
import 'package:url_launcher/url_launcher.dart';

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
          supportedLocales: const [Locale('en'), Locale('ne')],
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

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({
    super.key,
    required this.profile,
    required this.settings,
  });

  final RrydProfile profile;
  final RrydAppSettings settings;

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  final _locationService = RrydLocationService();
  final _rideRepository = RrydPassengerRideRepository();
  final _searchController = TextEditingController();
  final _chatController = TextEditingController();

  RrydLocationPoint? _pickup;
  RrydLocationPoint? _destination;
  RrydRouteResult? _route;
  RrydLocationPoint? _driverLocation;
  List<LatLng> _driverRoute = [];
  Map<String, dynamic>? _driverDetails;
  List<Map<String, dynamic>> _chatMessages = [];
  final Set<String> _knownChatMessageIds = {};
  Timer? _driverPollTimer;
  bool _loadingChat = false;
  bool _chatHasInitialSnapshot = false;
  bool _sendingMessage = false;
  StreamSubscription<Position>? _passengerLocationSubscription;
  int? _sharingLocationRideId;
  int? _locationDeclinedRideId;
  DateTime? _lastPassengerLocationWrite;
  bool _startingPassengerLocationShare = false;
  bool _loadingDriverDetails = false;
  String? _driverRouteKey;
  String? _activeRideRouteKey;
  List<RrydFareRule> _fareRules = [];
  List<Map<String, dynamic>> _rides = [];
  String _vehicleType = 'bike';
  String _pinTarget = 'pickup';
  String? _notice;
  bool _noticeIsError = false;
  bool _loading = true;
  bool _working = false;
  bool _searching = false;
  bool _loadingRoute = false;
  bool _loadingAvailability = false;
  bool _loadingRides = false;
  int? _availableCount;
  String? _displayName;

  static const _activeStatuses = {
    'requested',
    'accepted',
    'arriving',
    'started',
  };

  Map<String, dynamic>? get _activeRide {
    for (final ride in _rides) {
      if (_activeStatuses.contains(
        (ride['status'] ?? '').toString().toLowerCase(),
      )) {
        return ride;
      }
    }
    return null;
  }

  RrydFareRule? get _selectedFareRule {
    for (final rule in _fareRules) {
      if (rule.vehicleType == _vehicleType) return rule;
    }
    return null;
  }

  int? get _estimatedFare {
    final rule = _selectedFareRule;
    final route = _route;
    if (rule == null || route == null) return null;
    return rule.estimate(route.distanceKm);
  }

  @override
  void initState() {
    super.initState();
    _displayName = widget.profile.fullName;
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatController.dispose();
    _driverPollTimer?.cancel();
    _passengerLocationSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _showAccountSettings() async {
    final nameController = TextEditingController(
      text: _displayName ?? widget.profile.fullName,
    );
    final phoneController = TextEditingController(text: widget.profile.phone);
    bool saving = false;
    String? message;
    bool messageIsError = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Account settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        message!,
                        style: TextStyle(
                          color: messageIsError
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              if (name.length < 2 ||
                                  phone.length < 7 ||
                                  phone.length > 25) {
                                setSheetState(() {
                                  message =
                                      'Enter a valid name and phone number.';
                                  messageIsError = true;
                                });
                                return;
                              }

                              setSheetState(() {
                                saving = true;
                                message = null;
                              });
                              try {
                                final client = SupabaseBootstrap.client;
                                final nameResult = await client.rpc(
                                  'rydd_update_my_passenger_name',
                                  params: {'p_full_name': name},
                                );
                                if (nameResult == false) {
                                  throw StateError(
                                    'Supabase did not confirm the name update.',
                                  );
                                }
                                final phoneResult = await client.rpc(
                                  'rydd_update_my_phone',
                                  params: {'p_phone': phone},
                                );
                                if (phoneResult == false) {
                                  throw StateError(
                                    'Supabase did not confirm the phone update.',
                                  );
                                }
                                if (!mounted) return;
                                setState(() => _displayName = name);
                                setSheetState(() {
                                  message = 'Profile and phone saved.';
                                  messageIsError = false;
                                });
                              } catch (error) {
                                setSheetState(() {
                                  message = 'Could not save profile: $error';
                                  messageIsError = true;
                                });
                              } finally {
                                setSheetState(() => saving = false);
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(RrydStrings.of(context).text('save')),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final email =
                                  SupabaseBootstrap.client.auth.currentUser?.email;
                              if (email == null || email.isEmpty) {
                                setSheetState(() {
                                  message = 'No account email was found.';
                                  messageIsError = true;
                                });
                                return;
                              }
                              try {
                                await RrydAuthService().requestPasswordReset(
                                  email: email,
                                  appScheme: 'com.rryd.passenger',
                                );
                                setSheetState(() {
                                  message =
                                      'Password reset email requested. Check your inbox.';
                                  messageIsError = false;
                                });
                              } catch (error) {
                                setSheetState(() {
                                  message =
                                      'Password reset request failed: $error';
                                  messageIsError = true;
                                });
                              }
                            },
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Change password by email'),
                    ),
                    TextButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final first = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete passenger account?'),
                                  content: const Text(
                                    'This action may permanently delete your Rryd account and cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: Text(
                                        RrydStrings.of(dialogContext)
                                            .text('cancel'),
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Continue'),
                                    ),
                                  ],
                                ),
                              );
                              if (first != true || !context.mounted) return;
                              final finalConfirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Final confirmation'),
                                  content: const Text(
                                    'Permanently delete this account?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: Text(
                                        RrydStrings.of(dialogContext)
                                            .text('cancel'),
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Delete account'),
                                    ),
                                  ],
                                ),
                              );
                              if (finalConfirm != true || !context.mounted) {
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                final result = await SupabaseBootstrap.client
                                    .rpc('delete_own_account');
                                if (result == false) {
                                  throw StateError(
                                    'Supabase did not confirm account deletion.',
                                  );
                                }
                                await RrydAuthService().signOut();
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (error) {
                                setSheetState(() {
                                  message =
                                      'Account deletion was not confirmed: $error';
                                  messageIsError = true;
                                  saving = false;
                                });
                              }
                            },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete passenger account'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final rules = await _rideRepository.loadActiveFareRules();
      if (!mounted) return;
      setState(() {
        _fareRules = rules;
        _loading = false;
      });
      if (widget.profile.role == 'passenger') {
        await _refreshRides();
        await _checkAvailability();
      } else {
        _setNotice(
          RrydStrings.of(context).text('passenger_role_only'),
          isError: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _setNotice('Could not load Rryd data: $error', isError: true);
    }
  }

  void _setNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = isError;
    });
  }

  Future<void> _searchAddress() async {
    final strings = RrydStrings.of(context);
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final results =
          await _locationService.searchNepal(_searchController.text);
      if (!mounted) return;
      if (results.isEmpty) {
        _setNotice(strings.text('map_search_error'), isError: true);
        return;
      }
      final selected = await showModalBottomSheet<RrydPlaceSearchResult>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    strings.text('search_address'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(item.label),
                        subtitle: Text(
                          '${item.latitude.toStringAsFixed(5)}, '
                          '${item.longitude.toStringAsFixed(5)}',
                        ),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (selected == null || !mounted) return;
      _setSelectedPoint(selected.toPoint());
      _searchController.clear();
      _setNotice('Location selected: ${selected.label}');
    } catch (error) {
      _setNotice(
        '${strings.text('map_search_error')} ($error)',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _setSelectedPoint(RrydLocationPoint point) {
    setState(() {
      if (_pinTarget == 'pickup') {
        _pickup = point;
      } else {
        _destination = point;
      }
      _route = null;
      _availableCount = null;
    });
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (_working) return;
    try {
      final resolved = await _locationService.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted) return;
      _setSelectedPoint(resolved);
      _setNotice(
        '${_pinTarget == 'pickup' ? 'Pickup' : 'Destination'} selected: '
        '${resolved.label}',
      );
    } catch (error) {
      if (!mounted) return;
      _setNotice(
        'This map point could not be verified as inside Nepal. Choose another point or search for a Nepal address. ($error)',
        isError: true,
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_working) return;
    final strings = RrydStrings.of(context);
    setState(() => _working = true);
    try {
      final point = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _pickup = point;
        _pinTarget = 'destination';
        _route = null;
        _availableCount = null;
      });
      _setNotice('Pickup set to your current location: ${point.label}');
    } catch (error) {
      _setNotice('${strings.text('gps_error')} ($error)', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _calculateRoute() async {
    final strings = RrydStrings.of(context);
    if (_pickup == null || _destination == null) {
      _setNotice(strings.text('route_required'), isError: true);
      return;
    }
    setState(() => _loadingRoute = true);
    try {
      final route = await _locationService.getDrivingRoute(
        from: _pickup!,
        to: _destination!,
      );
      if (route.distanceKm > 500) {
        throw StateError('The selected route is longer than the 500 km limit.');
      }
      if (!mounted) return;
      setState(() => _route = route);
      _setNotice(
        'Road route calculated: ${route.distanceKm.toStringAsFixed(2)} km · '
        '${route.durationMinutes} min estimate.',
      );
      await _checkAvailability();
    } catch (error) {
      _setNotice('${strings.text('route_error')} ($error)', isError: true);
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _checkAvailability() async {
    if (widget.profile.role != 'passenger') return;
    setState(() => _loadingAvailability = true);
    try {
      final count =
          await _rideRepository.checkVehicleAvailability(_vehicleType);
      if (!mounted) return;
      setState(() => _availableCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _availableCount = null);
    } finally {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  Future<void> _refreshRides() async {
    if (widget.profile.role != 'passenger') return;
    setState(() => _loadingRides = true);
    try {
      final rows = await _rideRepository.loadMyRides(widget.profile.id);
      if (!mounted) return;
      setState(() => _rides = rows);
      await _restoreActiveRideLocations();
      if (_activeRide != null) {
        await _refreshDriverDetails();
        await _refreshRideMessages();
        await _syncPassengerLocationSharing();
        _startDriverPolling();
      } else {
        _stopDriverPolling();
        await _stopPassengerLocationSharing();
        setState(() {
          _driverDetails = null;
          _driverLocation = null;
          _driverRoute = [];
          _driverRouteKey = null;
          _activeRideRouteKey = null;
          _chatMessages = [];
          _knownChatMessageIds.clear();
          _chatHasInitialSnapshot = false;
        });
      }
    } catch (error) {
      _setNotice('Could not refresh your ride list: $error', isError: true);
    } finally {
      if (mounted) setState(() => _loadingRides = false);
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _restoreActiveRideLocations() async {
    final ride = _activeRide;
    if (ride == null) return;

    final pickupLat = _asDouble(ride['pickup_latitude']);
    final pickupLon = _asDouble(ride['pickup_longitude']);
    final destinationLat = _asDouble(ride['destination_latitude']);
    final destinationLon = _asDouble(ride['destination_longitude']);

    RrydLocationPoint? pickup;
    RrydLocationPoint? destination;
    if (pickupLat != null && pickupLon != null) {
      final point = RrydLocationPoint(
        label: (ride['pickup_location'] ?? 'Saved pickup').toString(),
        latitude: pickupLat,
        longitude: pickupLon,
      );
      if (point.isInsideNepal) pickup = point;
    }
    if (destinationLat != null && destinationLon != null) {
      final point = RrydLocationPoint(
        label: (ride['destination'] ?? 'Saved destination').toString(),
        latitude: destinationLat,
        longitude: destinationLon,
      );
      if (point.isInsideNepal) destination = point;
    }

    if (pickup == null || destination == null) {
      setState(() {
        _pickup = pickup;
        _destination = destination;
        _route = null;
        _driverRoute = [];
      });
      return;
    }
    final key = '${ride['id']}:${pickup.latitude.toStringAsFixed(5)}:'
        '${pickup.longitude.toStringAsFixed(5)}:'
        '${destination.latitude.toStringAsFixed(5)}:'
        '${destination.longitude.toStringAsFixed(5)}';
    if (_activeRideRouteKey == key && _route != null) return;

    setState(() {
      _pickup = pickup;
      _destination = destination;
      _route = null;
      _driverRoute = [];
      _activeRideRouteKey = key;
    });

    try {
      final route = await _locationService.getDrivingRoute(
        from: pickup,
        to: destination,
      );
      if (!mounted || _activeRide?['id'].toString() != ride['id'].toString()) return;
      setState(() => _route = route);
    } catch (_) {
      // The ride record and fixed pickup/destination markers remain available
      // even when a map-routing provider cannot return a route.
    }
  }

  void _startDriverPolling() {
    if (_driverPollTimer != null) return;
    _driverPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshRides(),
    );
  }

  void _stopDriverPolling() {
    _driverPollTimer?.cancel();
    _driverPollTimer = null;
  }

  Future<void> _refreshDriverDetails() async {
    final ride = _activeRide;
    if (ride == null ||
        ride['driver_id'] == null ||
        _loadingDriverDetails ||
        widget.profile.role != 'passenger') {
      return;
    }

    final rideId = int.tryParse(ride['id'].toString());
    if (rideId == null) return;
    _loadingDriverDetails = true;
    try {
      final details =
          await _rideRepository.loadDriverDetailsForRide(rideId);
      if (!mounted || _activeRide?['id'].toString() != rideId.toString()) {
        return;
      }
      if (details == null) {
        setState(() {
          _driverDetails = null;
          _driverLocation = null;
          _driverRoute = [];
        });
        return;
      }

      final latitude = _asDouble(
        details['driver_latitude'] ??
            details['current_latitude'] ??
            details['latitude'],
      );
      final longitude = _asDouble(
        details['driver_longitude'] ??
            details['current_longitude'] ??
            details['longitude'],
      );
      final updatedRaw =
          details['location_updated_at'] ?? details['updated_at'];
      final updatedAt =
          updatedRaw == null ? null : DateTime.tryParse(updatedRaw.toString());
      final fresh = updatedAt != null &&
          DateTime.now().difference(updatedAt).inSeconds >= 0 &&
          DateTime.now().difference(updatedAt) <
              const Duration(minutes: 2);

      RrydLocationPoint? driverPoint;
      if (latitude != null && longitude != null) {
        final candidate = RrydLocationPoint(
          label: (details['driver_name'] ?? 'Assigned driver').toString(),
          latitude: latitude,
          longitude: longitude,
        );
        if (candidate.isInsideNepal && fresh) driverPoint = candidate;
      }

      setState(() {
        _driverDetails = details;
        _driverLocation = driverPoint;
      });

      final status = (_activeRide?['status'] ?? '').toString().toLowerCase();
      if (driverPoint != null &&
          _pickup != null &&
          (status == 'accepted' || status == 'arriving')) {
        final key = '${rideId}:${driverPoint.latitude.toStringAsFixed(3)}:'
            '${driverPoint.longitude.toStringAsFixed(3)}:'
            '${_pickup!.latitude.toStringAsFixed(5)}:'
            '${_pickup!.longitude.toStringAsFixed(5)}';
        if (_driverRouteKey != key) {
          _driverRouteKey = key;
          try {
            final route = await _locationService.getDrivingRoute(
              from: driverPoint,
              to: _pickup!,
            );
            if (!mounted ||
                _activeRide?['id'].toString() != rideId.toString()) return;
            setState(() => _driverRoute = route.points);
          } catch (_) {
            if (mounted) setState(() => _driverRoute = []);
          }
        }
      } else {
        setState(() {
          _driverRoute = [];
          _driverRouteKey = null;
        });
      }
    } catch (error) {
      if (mounted) {
        _setNotice(
          'Assigned driver details are not available right now: $error',
          isError: true,
        );
      }
    } finally {
      _loadingDriverDetails = false;
    }
  }

  Future<void> _syncPassengerLocationSharing() async {
    final ride = _activeRide;
    if (ride == null || ride['driver_id'] == null) {
      await _stopPassengerLocationSharing();
      return;
    }
    final status = (ride['status'] ?? '').toString().toLowerCase();
    if (status == 'accepted') {
      await _startPassengerLocationSharing(ride);
    } else {
      await _stopPassengerLocationSharing();
    }
  }

  Future<void> _startPassengerLocationSharing(
    Map<String, dynamic> ride,
  ) async {
    final rideId = int.tryParse(ride['id'].toString());
    if (rideId == null ||
        _startingPassengerLocationShare ||
        _sharingLocationRideId == rideId ||
        !mounted) {
      return;
    }
    if (_locationDeclinedRideId == rideId) return;

    _startingPassengerLocationShare = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Share pickup location?'),
          content: const Text(
            'Your live GPS location will be shared only with the driver assigned to this ride while they are coming to pick you up. Sharing stops when the driver marks arriving.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Share for this ride'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) {
        _locationDeclinedRideId = rideId;
        _setNotice('Live pickup location was not shared. You can enable it from the active ride card.');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Turn on Location Services to share pickup location.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission was not granted.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is blocked. Enable it in your phone settings.',
        );
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!_isValidNepalCoordinate(current.latitude, current.longitude)) {
        throw StateError('Your GPS position is outside the supported Nepal area.');
      }
      // Verify the first share point by reverse geocoding. Later GPS updates
      // are constrained to the same Nepal coordinate bounds.
      await _locationService.reverseGeocode(
        latitude: current.latitude,
        longitude: current.longitude,
      );
      if (!mounted ||
          _activeRide?['id'].toString() != rideId.toString() ||
          (_activeRide?['status'] ?? '').toString().toLowerCase() != 'accepted') {
        return;
      }

      await _publishPassengerLocation(rideId, current);
      _sharingLocationRideId = rideId;
      _locationDeclinedRideId = null;
      _passengerLocationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen(
        (position) => _publishPassengerLocation(rideId, position),
        onError: (Object error) {
          if (mounted) {
            _setNotice(
              'Live pickup location sharing paused: $error',
              isError: true,
            );
          }
        },
      );
      _setNotice(
        'Live pickup location is being shared with your assigned driver until they mark arriving.',
      );
    } catch (error) {
      _locationDeclinedRideId = rideId;
      _setNotice(
        'Could not start live pickup location sharing: $error',
        isError: true,
      );
    } finally {
      _startingPassengerLocationShare = false;
    }
  }

  bool _isValidNepalCoordinate(double latitude, double longitude) =>
      latitude >= 26 &&
      latitude <= 31 &&
      longitude >= 80 &&
      longitude <= 89;

  Future<void> _publishPassengerLocation(
    int rideId,
    Position position,
  ) async {
    final ride = _activeRide;
    if (ride == null ||
        ride['id'].toString() != rideId.toString() ||
        (ride['status'] ?? '').toString().toLowerCase() != 'accepted') {
      await _stopPassengerLocationSharing();
      return;
    }
    if (!_isValidNepalCoordinate(position.latitude, position.longitude)) {
      _setNotice('GPS moved outside the supported Nepal area. Sharing paused.',
          isError: true);
      await _stopPassengerLocationSharing();
      return;
    }

    final last = _lastPassengerLocationWrite;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _lastPassengerLocationWrite = DateTime.now();
    try {
      await _rideRepository.updateMyPassengerLocation(
        rideId: rideId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      if (mounted) {
        _setNotice(
          'Your location was not shared with the driver: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _stopPassengerLocationSharing() async {
    await _passengerLocationSubscription?.cancel();
    _passengerLocationSubscription = null;
    _sharingLocationRideId = null;
    _lastPassengerLocationWrite = null;
  }

  Future<void> _refreshRideMessages() async {
    final ride = _activeRide;
    if (ride == null ||
        _loadingChat ||
        widget.profile.role != 'passenger' ||
        ride['driver_id'] == null) return;
    final status = (ride['status'] ?? '').toString().toLowerCase();
    if (!{'accepted', 'arriving', 'started'}.contains(status)) return;
    final rideId = int.tryParse(ride['id'].toString());
    if (rideId == null) return;

    _loadingChat = true;
    try {
      final messages = await _rideRepository.loadRideMessages(rideId);
      if (!mounted || _activeRide?['id'].toString() != rideId.toString()) {
        return;
      }
      final ids = messages
          .map((message) => (message['id'] ??
                  '${message['created_at']}:'
                      '${message['sender_id']}:'
                      '${message['message']}')
              .toString())
          .toSet();
      if (_chatHasInitialSnapshot) {
        final incoming = messages.any((message) {
          final id = (message['id'] ??
                  '${message['created_at']}:'
                      '${message['sender_id']}:'
                      '${message['message']}')
              .toString();
          return !_knownChatMessageIds.contains(id) &&
              message['sender_id'].toString() != widget.profile.id;
        });
        if (incoming) SystemSound.play(SystemSoundType.alert);
      }
      setState(() {
        _chatMessages = messages;
        _knownChatMessageIds
          ..clear()
          ..addAll(ids);
        _chatHasInitialSnapshot = true;
      });
    } catch (error) {
      if (mounted) _setNotice('Ride chat is unavailable: $error', isError: true);
    } finally {
      _loadingChat = false;
    }
  }

  Future<void> _sendRideMessage() async {
    final ride = _activeRide;
    if (ride == null || _sendingMessage) return;
    final status = (ride['status'] ?? '').toString().toLowerCase();
    if (!{'accepted', 'arriving', 'started'}.contains(status)) {
      _setNotice('Chat is available only for your assigned active ride.',
          isError: true);
      return;
    }
    final clean = _chatController.text.trim();
    if (clean.isEmpty) return;
    if (clean.length > 1000) {
      _setNotice('Messages can contain at most 1000 characters.',
          isError: true);
      return;
    }
    final rideId = int.tryParse(ride['id'].toString());
    if (rideId == null) {
      _setNotice('Ride ID is not in the expected format.', isError: true);
      return;
    }
    setState(() => _sendingMessage = true);
    try {
      await _rideRepository.sendRideMessage(
        rideId: rideId,
        senderId: widget.profile.id,
        message: clean,
      );
      _chatController.clear();
      await _refreshRideMessages();
      _setNotice('Message saved to this ride chat.');
    } catch (error) {
      _setNotice('Message was not sent: $error', isError: true);
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Widget _rideChatCard(ThemeData theme) {
    final status = (_activeRide?['status'] ?? '').toString().toLowerCase();
    final chatAvailable =
        {'accepted', 'arriving', 'started'}.contains(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ride chat',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _chatMessages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No messages yet.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        final mine =
                            message['sender_id'].toString() == widget.profile.id;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(10),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: mine
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text((message['message'] ?? '').toString()),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    enabled: chatAvailable && !_sendingMessage,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message driver',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _sendRideMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: !chatAvailable || _sendingMessage
                      ? null
                      : _sendRideMessage,
                  icon: _sendingMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
            Text(
              'Only messages confirmed by Supabase are shown. Chat access is restricted by ride_messages policies.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callDriver() async {
    final phone = (_driverDetails?['driver_phone'] ??
            _driverDetails?['phone'] ??
            '')
        .toString()
        .replaceAll(RegExp(r'[^+0-9]'), '');
    if (phone.isEmpty) {
      _setNotice('The assigned driver contact number is not available.',
          isError: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final opened = await launchUrl(uri);
      if (!opened) throw StateError('The phone dialer could not be opened.');
    } catch (error) {
      _setNotice('Could not open the phone dialer: $error', isError: true);
    }
  }

  Future<void> _requestRide() async {
    final strings = RrydStrings.of(context);
    if (widget.profile.role != 'passenger') {
      _setNotice(strings.text('passenger_role_only'), isError: true);
      return;
    }
    if (_activeRide != null) {
      _setNotice(strings.text('one_active_ride'), isError: true);
      return;
    }
    if (_pickup == null || _destination == null || _route == null) {
      _setNotice(strings.text('route_required'), isError: true);
      return;
    }
    if (_selectedFareRule == null || _estimatedFare == null) {
      _setNotice(strings.text('fare_not_loaded'), isError: true);
      return;
    }

    setState(() => _working = true);
    try {
      await _rideRepository.requestRide(
        pickup: _pickup!,
        destination: _destination!,
        vehicleType: _vehicleType,
        distanceKm: _route!.distanceKm,
        paymentMethod: 'cash',
      );
      await _refreshRides();
      if (!mounted) return;
      _setNotice(strings.text('ride_requested'));
    } catch (error) {
      _setNotice('Ride request was not confirmed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelRide() async {
    final ride = _activeRide;
    if (ride == null) return;
    final rideId = int.tryParse(ride['id'].toString());
    if (rideId == null) {
      _setNotice('Ride ID is not in the expected format.', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text('Do you want to cancel this ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(RrydStrings.of(context).text('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      await _rideRepository.cancelRide(rideId);
      await _refreshRides();
      _setNotice('Cancellation was confirmed by Rryd.');
    } catch (error) {
      _setNotice('Cancellation was not confirmed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RrydStrings.of(context);
    final theme = Theme.of(context);
    final rule = _selectedFareRule;
    final fare = _estimatedFare;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rryd'),
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
            onPressed: () =>
                widget.settings.setLightTheme(!widget.settings.useLightTheme),
            icon: Icon(
              widget.settings.useLightTheme
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Account settings',
            onPressed: _showAccountSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: strings.text('sign_out'),
            onPressed: () => RrydAuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadInitialData();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Text(
                    '${strings.text('welcome')}, '
                    '${(_displayName ?? widget.profile.fullName).isEmpty ? 'Passenger' : (_displayName ?? widget.profile.fullName)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_noticeIsError
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _notice!,
                        style: TextStyle(
                          color: _noticeIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    strings.text('booking_next'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _mapNotice(strings),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 330,
                    child: RrydTripMap(
                      pickup: _pickup,
                      destination: _destination,
                      route: _route?.points ?? const [],
                      driverLocation: _driverLocation,
                      driverRoute: _driverRoute,
                      onMapTap: _handleMapTap,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _targetButton(
                          label: strings.text('choose_pickup'),
                          selected: _pinTarget == 'pickup',
                          icon: Icons.trip_origin,
                          onTap: () => setState(() => _pinTarget = 'pickup'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _targetButton(
                          label: strings.text('choose_destination'),
                          selected: _pinTarget == 'destination',
                          icon: Icons.location_on,
                          onTap: () =>
                              setState(() => _pinTarget = 'destination'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: InputDecoration(
                      labelText: strings.text('search_address'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _searching ? null : _searchAddress,
                        icon: _searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(strings.text('use_gps')),
                  ),
                  const SizedBox(height: 10),
                  _locationCard(strings.text('pickup'), _pickup),
                  const SizedBox(height: 8),
                  _locationCard(strings.text('destination'), _destination),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loadingRoute ? null : _calculateRoute,
                    icon: _loadingRoute
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.alt_route),
                    label: Text(strings.text('calculate_route')),
                  ),
                  if (_route != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            strings.text('route_distance'),
                            '${_route!.distanceKm.toStringAsFixed(2)} km',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metricCard(
                            strings.text('estimated_time'),
                            '${_route!.durationMinutes} min',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    strings.text('select_vehicle'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _vehicleChoice('bike', strings.text('bike'), Icons.two_wheeler),
                      _vehicleChoice('car', strings.text('car'), Icons.directions_car),
                      _vehicleChoice('tuk_tuk', strings.text('tuk_tuk'), Icons.electric_rickshaw),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.text('estimated_fare'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fare == null ? 'NPR —' : 'NPR $fare',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: RrydTheme.orange,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            rule == null
                                ? strings.text('fare_not_loaded')
                                : 'NPR ${rule.baseFare.toStringAsFixed(0)} base + '
                                    'NPR ${rule.perKmFare.toStringAsFixed(0)}/km',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.text('rounding_notice'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(strings.text('payment_cash_only'))),
                      Chip(label: Text(strings.text('cash'))),
                    ],
                  ),
                  Text(
                    strings.text('online_unavailable'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingAvailability)
                    const LinearProgressIndicator()
                  else if (_availableCount != null)
                    Text(
                      _availableCount! > 0
                          ? '${strings.text('availability')}: $_availableCount'
                          : strings.text('no_availability'),
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _working ||
                            _route == null ||
                            fare == null ||
                            widget.profile.role != 'passenger' ||
                            _activeRide != null
                        ? null
                        : _requestRide,
                    icon: _working
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.local_taxi_outlined),
                    label: Text(strings.text('request_ride')),
                  ),
                  if (_activeRide != null) ...[
                    const SizedBox(height: 22),
                    _activeRideCard(strings, theme),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.text('ride_history'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.text('refresh'),
                        onPressed: _loadingRides ? null : _refreshRides,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (_rides.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(strings.text('no_rides')),
                    )
                  else
                    ..._rides.map((ride) => _rideHistoryCard(ride, theme)),
                ],
              ),
            ),
    );
  }

  Widget _mapNotice(RrydStrings strings) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.text('map_service_notice'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetButton({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? RrydTheme.orange.withValues(alpha: 0.12)
            : null,
        side: BorderSide(
          color: selected ? RrydTheme.orange : Theme.of(context).dividerColor,
        ),
      ),
    );
  }

  Widget _locationCard(String title, RrydLocationPoint? point) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          title == RrydStrings.of(context).text('pickup')
              ? Icons.trip_origin
              : Icons.location_on,
          color: title == RrydStrings.of(context).text('pickup')
              ? const Color(0xFF16B981)
              : RrydTheme.orange,
        ),
        title: Text(title, style: theme.textTheme.labelMedium),
        subtitle: Text(
          point?.label ?? 'Not selected',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleChoice(String value, String label, IconData icon) {
    return ChoiceChip(
      selected: _vehicleType == value,
      avatar: Icon(icon, size: 19),
      label: Text(label),
      onSelected: (selected) {
        if (!selected) return;
        setState(() {
          _vehicleType = value;
          _availableCount = null;
        });
        _checkAvailability();
      },
    );
  }

  Widget _activeRideCard(RrydStrings strings, ThemeData theme) {
    final ride = _activeRide!;
    final status = (ride['status'] ?? 'unknown').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.text('active_ride'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(status.toUpperCase())),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${ride['pickup_location'] ?? 'Pickup'} → '
              '${ride['destination'] ?? 'Destination'}',
            ),
            const SizedBox(height: 6),
            Text(
              '${strings.text('ride_id')}: ${ride['id']}',
              style: theme.textTheme.bodySmall,
            ),
            if (_driverDetails != null) ...[
              const SizedBox(height: 12),
              _driverContactCard(strings, theme),
            ],
            if (ride['driver_id'] != null &&
                {'accepted', 'arriving', 'started'}.contains(status)) ...[
              const SizedBox(height: 12),
              if (status == 'accepted') ...[
                Text(
                  _sharingLocationRideId == int.tryParse(ride['id'].toString())
                      ? 'Live pickup location is being shared with your assigned driver.'
                      : 'Your pickup location is not currently being shared.',
                  style: theme.textTheme.bodySmall,
                ),
                if (_sharingLocationRideId !=
                    int.tryParse(ride['id'].toString()))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _startingPassengerLocationShare
                          ? null
                          : () => _startPassengerLocationSharing(ride),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Share pickup location with driver'),
                    ),
                  ),
              ] else
                Text(
                  'Live pickup location sharing has stopped because the driver marked arriving or started the trip.',
                  style: theme.textTheme.bodySmall,
                ),
              _rideChatCard(theme),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingRides ? null : _refreshRides,
                  icon: const Icon(Icons.refresh),
                  label: Text(strings.text('refresh')),
                ),
                const SizedBox(width: 8),
                if (status == 'requested' ||
                    status == 'accepted' ||
                    status == 'arriving')
                  TextButton(
                    onPressed: _working ? null : _cancelRide,
                    child: const Text('Cancel ride'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverContactCard(RrydStrings strings, ThemeData theme) {
    final details = _driverDetails ?? const <String, dynamic>{};
    final name =
        (details['driver_name'] ?? details['full_name'] ?? 'Assigned driver')
            .toString();
    final vehicle =
        (details['vehicle_type'] ?? _activeRide?['vehicle_type'] ?? '').toString();
    final model =
        (details['vehicle_model'] ?? details['model'] ?? '').toString();
    final number = (details['vehicle_registration'] ??
            details['vehicle_number'] ??
            '')
        .toString();
    final phone =
        (details['driver_phone'] ?? details['phone'] ?? '').toString();
    final locationUpdated = details['location_updated_at']?.toString() ?? '';
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned driver',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(name),
            if (vehicle.isNotEmpty || model.isNotEmpty)
              Text('${vehicle.toUpperCase()} ${model.isEmpty ? '' : '· $model'}'),
            if (number.isNotEmpty) Text('Registration: $number'),
            if (locationUpdated.isNotEmpty)
              Text(
                'Location update: $locationUpdated',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (phone.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _callDriver,
                  icon: const Icon(Icons.call),
                  label: const Text('Call driver'),
                ),
              )
            else
              Text(
                'Driver phone is not available.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _rideHistoryCard(Map<String, dynamic> ride, ThemeData theme) {
    final status = (ride['status'] ?? 'unknown').toString();
    final date = ride['created_at']?.toString() ?? '';
    final fare = ride['final_fare'] ?? ride['fare'] ?? ride['estimated_fare'];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route_outlined),
        title: Text(
          '${ride['pickup_location'] ?? 'Pickup'} → '
          '${ride['destination'] ?? 'Destination'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Ride #${ride['id']} · $status'
          '${date.isEmpty ? '' : ' · $date'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: fare == null ? null : Text('NPR ${fare.toString()}'),
      ),
    );
  }
}
