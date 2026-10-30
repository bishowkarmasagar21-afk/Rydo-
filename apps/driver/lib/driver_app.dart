import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rryd_core/rryd_core.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key, required this.settings});
  final RrydAppSettings settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          title: 'Rryd Driver',
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
            appRole: 'driver',
            appTitle: 'Rryd Driver',
            appScheme: 'com.rryd.driver',
            settings: settings,
            allowPassengerRegistration: false,
            allowDriverRegistration: true,
            homeBuilder: (context, profile) =>
                DriverHomePage(profile: profile, settings: settings),
          ),
        ),
      );
}

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({
    super.key,
    required this.profile,
    required this.settings,
  });
  final RrydProfile profile;
  final RrydAppSettings settings;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final _repository = RrydDriverRepository();
  final _locationService = RrydLocationService();
  final _chatController = TextEditingController();
  final _vehicleFormKey = GlobalKey<FormState>();
  final _vehicleModelController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final Set<String> _knownRequestIds = {};
  String _newVehicleType = 'bike';
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _myRides = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _chatMessages = [];
  Map<String, dynamic>? _passengerDetails;
  RrydLocationPoint? _driverPoint;
  RrydLocationPoint? _pickupPoint;
  RrydLocationPoint? _destinationPoint;
  RrydLocationPoint? _passengerPoint;
  List<LatLng> _routeToPassenger = [];
  final Set<String> _knownChatMessageIds = {};
  StreamSubscription<Position>? _locationSubscription;
  Timer? _pollTimer;
  DateTime? _lastLocationWrite;
  bool _online = false;
  bool _loading = true;
  bool _busy = false;
  bool _hasInitialRequestSnapshot = false;
  bool _requestReadFailed = false;
  bool _loadingCommunication = false;
  bool _sendingMessage = false;
  bool _chatHasInitialSnapshot = false;
  String _communicationStatus = 'No active ride chat.';
  String? _notice;
  bool _noticeIsError = false;
  String _gpsStatus = '';
  String? _passengerRouteKey;

  static const _activeStatuses = {'accepted', 'arriving', 'started'};

  Map<String, dynamic>? get _activeRide {
    for (final ride in _myRides) {
      if (_activeStatuses.contains(
        (ride['status'] ?? '').toString().toLowerCase(),
      )) return ride;
    }
    return null;
  }

  List<Map<String, dynamic>> get _approvedVehicles => _vehicles
      .where((vehicle) => vehicle['is_approved'] == true)
      .toList(growable: false);

  Set<String> get _approvedVehicleTypes => _approvedVehicles
      .map((vehicle) => (vehicle['vehicle_type'] ?? '').toString())
      .toSet();

  List<Map<String, dynamic>> get _completedRides => _myRides
      .where((ride) =>
          (ride['status'] ?? '').toString().toLowerCase() == 'completed')
      .toList(growable: false);

  double _sumField(Iterable<Map<String, dynamic>> rows, String key) =>
      rows.fold<double>(
        0,
        (sum, row) => sum + ((row[key] as num?)?.toDouble() ?? 0),
      );

  @override
  void initState() {
    super.initState();
    _online = widget.profile.isOnline;
    _loadData(initial: true).then((_) {
      if (!mounted) return;
      if (_online) _startLocationUpdates();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationSubscription?.cancel();
    _locationService.dispose();
    _chatController.dispose();
    _vehicleModelController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  void _setNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = isError;
    });
  }

  Future<void> _loadData({bool initial = false}) async {
    if (initial && mounted) setState(() => _loading = true);
    try {
      final vehicles = await _repository.loadVehicles(widget.profile.id);
      if (!mounted) return;
      setState(() => _vehicles = vehicles);
    } catch (error) {
      _setNotice('Could not load your registered vehicles: $error',
          isError: true);
    }

    try {
      final rides = await _repository.loadMyRides(widget.profile.id);
      if (!mounted) return;
      setState(() => _myRides = rides);
      await _refreshRideCommunication();
    } catch (error) {
      _setNotice('Could not load your ride history: $error', isError: true);
    }

    if (_online) {
      try {
        final requests = await _repository.loadRideRequests();
        if (!mounted) return;
        final requestIds = requests.map((r) => r['id'].toString()).toSet();
        if (_hasInitialRequestSnapshot) {
          final newIds = requestIds.difference(_knownRequestIds);
          if (newIds.isNotEmpty) {
            SystemSound.play(SystemSoundType.alert);
            for (final request in requests) {
              if (!newIds.contains(request['id'].toString())) continue;
              final rideId = int.tryParse(request['id'].toString());
              if (rideId == null) continue;
              try {
                await RrydNotificationService.showRideRequest(
                  rideId: rideId,
                  pickup: (request['pickup_location'] ?? 'Pickup').toString(),
                  destination: (request['destination'] ?? 'Destination').toString(),
                  vehicleType: (request['vehicle_type'] ?? '').toString(),
                );
              } catch (error) {
                _setNotice(
                  'A new ride was found, but the notification could not be displayed: $error',
                  isError: true,
                );
              }
            }
            _setNotice(
              '${newIds.length} new ride request(s). Review the details before accepting.',
            );
          }
        }
        _knownRequestIds
          ..clear()
          ..addAll(requestIds);
        _hasInitialRequestSnapshot = true;
        setState(() {
          _requests = requests;
          _requestReadFailed = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _requests = [];
          _requestReadFailed = true;
        });
        _setNotice(
          'Could not load incoming ride requests: $error. '
          'The rides SELECT policy must allow verified eligible drivers to '
          'read unassigned requested rides.',
          isError: true,
        );
      }
    } else {
      if (mounted) setState(() => _requests = []);
    }
    if (initial && mounted) setState(() => _loading = false);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || (!_online && _activeRide == null)) return;
      _loadData();
    });
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Turn on Location Services before going online.');
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
        'Location permission is blocked. Enable it in phone settings.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.latitude < 26 ||
        position.latitude > 31 ||
        position.longitude < 80 ||
        position.longitude > 89) {
      throw StateError('Driver GPS is outside the supported Nepal area.');
    }
    return position;
  }

  Future<void> _sendLocation(Position position) async {
    final point = RrydLocationPoint(
      label: 'Driver location',
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (point.isInsideNepal) {
      if (mounted) setState(() => _driverPoint = point);
    }

    final last = _lastLocationWrite;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastLocationWrite = DateTime.now();
    try {
      await _repository.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        setState(() {
          _gpsStatus =
              'GPS updated · ${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (error) {
      _setNotice('GPS was obtained but the server update failed: $error',
          isError: true);
    }
  }

  Future<void> _startLocationUpdates() async {
    await _locationSubscription?.cancel();
    try {
      final current = await _getCurrentPosition();
      await _sendLocation(current);
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        _sendLocation,
        onError: (Object error) =>
            _setNotice('Live GPS update stopped: $error', isError: true),
      );
    } catch (error) {
      _setNotice('GPS tracking is unavailable: $error', isError: true);
    }
  }

  Future<void> _showDriverSettings() async {
    final nameController =
        TextEditingController(text: widget.profile.fullName);
    final phoneController = TextEditingController(text: widget.profile.phone);
    bool saving = false;
    String? message;
    bool isError = false;

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
                      'Driver account settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        message!,
                        style: TextStyle(
                          color: isError
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
                                  isError = true;
                                });
                                return;
                              }
                              setSheetState(() {
                                saving = true;
                                message = null;
                              });
                              try {
                                await SupabaseBootstrap.client
                                    .from('profiles')
                                    .update({
                                      'full_name': name,
                                      'phone': phone,
                                    })
                                    .eq('id', widget.profile.id);
                                if (!mounted) return;
                                setSheetState(() {
                                  message = 'Profile and phone saved.';
                                  isError = false;
                                });
                                await _loadData();
                              } catch (error) {
                                setSheetState(() {
                                  message = 'Profile update failed: $error';
                                  isError = true;
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
                          : const Text('Save profile'),
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
                                  isError = true;
                                });
                                return;
                              }
                              try {
                                await RrydAuthService().requestPasswordReset(
                                  email: email,
                                  appScheme: 'com.rryd.driver',
                                );
                                setSheetState(() {
                                  message =
                                      'Password reset email requested. Check your inbox.';
                                  isError = false;
                                });
                              } catch (error) {
                                setSheetState(() {
                                  message =
                                      'Password reset request failed: $error';
                                  isError = true;
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete driver account?'),
                                  content: const Text(
                                    'This action may permanently delete your Rryd account. Any active ride must be resolved first.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Continue'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true || !context.mounted) return;
                              final finalConfirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Final confirmation'),
                                  content: const Text(
                                    'Permanently delete this driver account?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
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
                                  isError = true;
                                  saving = false;
                                });
                              }
                            },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete driver account'),
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

  Future<void> _toggleOnline() async {
    if (_busy) return;
    final goingOnline = !_online;
    if (goingOnline) {
      if (!widget.profile.isVerified || widget.profile.isSuspended) {
        _setNotice(
          'Your driver profile must be verified and not suspended before going online.',
          isError: true,
        );
        return;
      }
      if (_approvedVehicles.isEmpty) {
        _setNotice(
          'Register a vehicle and wait for admin approval before going online.',
          isError: true,
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      Position? position;
      if (goingOnline) {
        position = await _getCurrentPosition();
        // Permission denial does not block a driver from going online, but
        // the app will warn that system notifications may not be displayed.
        await RrydNotificationService.requestPermission();
      }
      await _repository.setOnline(goingOnline);
      if (!mounted) return;
      setState(() {
        _online = goingOnline;
        _gpsStatus = goingOnline
            ? RrydStrings.of(context).text('location_sending')
            : RrydStrings.of(context).text('location_stopped');
      });
      if (goingOnline && position != null) {
        await _sendLocation(position);
        await _startLocationUpdates();
        _setNotice('You are online and eligible to receive ride requests.');
      } else {
        await _locationSubscription?.cancel();
        _locationSubscription = null;
        setState(() => _requests = []);
        _setNotice('You are now offline.');
      }
      await _loadData();
    } catch (error) {
      _setNotice('Could not change online status: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitVehicle() async {
    if (_busy || !_vehicleFormKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _repository.registerVehicle(
        driverId: widget.profile.id,
        vehicleType: _newVehicleType,
        vehicleModel: _vehicleModelController.text.trim(),
        vehicleNumber: _vehicleNumberController.text.trim(),
      );
      _vehicleModelController.clear();
      _vehicleNumberController.clear();
      await _loadData();
      _setNotice(
        'Vehicle submitted. It cannot be used for ride requests until Rryd Admin approves it.',
      );
    } catch (error) {
      _setNotice('Vehicle could not be submitted: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double? _coordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  RrydLocationPoint? _ridePoint(
    Map<String, dynamic> ride, {
    required String labelKey,
    required String latitudeKey,
    required String longitudeKey,
    required String defaultLabel,
  }) {
    final latitude = _coordinate(ride[latitudeKey]);
    final longitude = _coordinate(ride[longitudeKey]);
    if (latitude == null || longitude == null) return null;
    final point = RrydLocationPoint(
      label: (ride[labelKey] ?? defaultLabel).toString(),
      latitude: latitude,
      longitude: longitude,
    );
    return point.isInsideNepal ? point : null;
  }

  Future<void> _refreshRideCommunication() async {
    final ride = _activeRide;
    if (ride == null) {
      if (!mounted) return;
      setState(() {
        _passengerDetails = null;
        _passengerPoint = null;
        _pickupPoint = null;
        _destinationPoint = null;
        _routeToPassenger = [];
        _passengerRouteKey = null;
        _chatMessages = [];
        _knownChatMessageIds.clear();
        _chatHasInitialSnapshot = false;
        _communicationStatus = 'No active ride chat.';
      });
      return;
    }

    final rideId = int.tryParse(ride['id'].toString());
    if (rideId == null || _loadingCommunication) return;
    _loadingCommunication = true;

    try {
      final pickup = _ridePoint(
        ride,
        labelKey: 'pickup_location',
        latitudeKey: 'pickup_latitude',
        longitudeKey: 'pickup_longitude',
        defaultLabel: 'Confirmed pickup',
      );
      final destination = _ridePoint(
        ride,
        labelKey: 'destination',
        latitudeKey: 'destination_latitude',
        longitudeKey: 'destination_longitude',
        defaultLabel: 'Destination',
      );
      if (mounted) {
        setState(() {
          _pickupPoint = pickup;
          _destinationPoint = destination;
        });
      }

      // Passenger details are retrieved only through the ride-scoped RPC.
      try {
        final details =
            await _repository.loadPassengerDetailsForRide(rideId);
        if (mounted && _activeRide?['id'].toString() == rideId.toString()) {
          setState(() => _passengerDetails = details);
        }
      } catch (error) {
        if (mounted) {
          setState(() => _passengerDetails = null);
          _setNotice(
            'Passenger contact is unavailable: $error',
            isError: true,
          );
        }
      }

      final status = (ride['status'] ?? '').toString().toLowerCase();
      if (status == 'accepted') {
        try {
          final location =
              await _repository.loadPassengerLocationForRide(rideId);
          final latitude = _coordinate(
            location?['latitude'] ??
                location?['passenger_latitude'] ??
                location?['current_latitude'],
          );
          final longitude = _coordinate(
            location?['longitude'] ??
                location?['passenger_longitude'] ??
                location?['current_longitude'],
          );
          final updatedRaw = location?['updated_at'] ??
              location?['location_updated_at'] ??
              location?['created_at'];
          final updated = updatedRaw == null
              ? null
              : DateTime.tryParse(updatedRaw.toString());
          final fresh = updated != null &&
              DateTime.now().difference(updated).inSeconds >= 0 &&
              DateTime.now().difference(updated) <
                  const Duration(minutes: 2);

          RrydLocationPoint? point;
          if (latitude != null && longitude != null && fresh) {
            final candidate = RrydLocationPoint(
              label: 'Passenger shared location',
              latitude: latitude,
              longitude: longitude,
            );
            if (candidate.isInsideNepal) point = candidate;
          }

          if (!mounted ||
              _activeRide?['id'].toString() != rideId.toString()) return;
          setState(() {
            _passengerPoint = point;
            _communicationStatus = point == null
                ? 'Waiting for a fresh passenger pickup location.'
                : 'Passenger pickup location is fresh.';
          });

          if (point != null && _driverPoint != null) {
            final key = '${rideId}:'
                '${point.latitude.toStringAsFixed(4)}:'
                '${point.longitude.toStringAsFixed(4)}:'
                '${_driverPoint!.latitude.toStringAsFixed(4)}:'
                '${_driverPoint!.longitude.toStringAsFixed(4)}';
            if (_passengerRouteKey != key) {
              _passengerRouteKey = key;
              try {
                final route = await _locationService.getDrivingRoute(
                  from: _driverPoint!,
                  to: point,
                );
                if (mounted &&
                    _activeRide?['id'].toString() == rideId.toString()) {
                  setState(() => _routeToPassenger = route.points);
                }
              } catch (_) {
                if (mounted) setState(() => _routeToPassenger = []);
              }
            }
          } else if (mounted) {
            setState(() {
              _routeToPassenger = [];
              _passengerRouteKey = null;
            });
          }
        } catch (error) {
          if (mounted) {
            setState(() {
              _passengerPoint = null;
              _routeToPassenger = [];
              _passengerRouteKey = null;
              _communicationStatus =
                  'Passenger pickup location is unavailable: $error';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _passengerPoint = null;
            _routeToPassenger = [];
            _passengerRouteKey = null;
            _communicationStatus =
                'Live pickup sharing is stopped. The confirmed pickup pin remains visible.';
          });
        }
      }

      if (_activeStatuses.contains(status)) {
        try {
          final messages = await _repository.loadRideMessages(rideId);
          if (!mounted ||
              _activeRide?['id'].toString() != rideId.toString()) return;
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
            _communicationStatus =
                'Ride chat · ${messages.length} message(s)';
          });
        } catch (error) {
          if (mounted) {
            setState(() {
              _communicationStatus =
                  'Chat unavailable. Check ride_messages access and RLS: $error';
              _chatMessages = [];
            });
          }
        }
      }
    } finally {
      _loadingCommunication = false;
    }
  }

  Future<void> _sendRideMessage() async {
    final ride = _activeRide;
    if (ride == null || _sendingMessage) return;
    final status = (ride['status'] ?? '').toString().toLowerCase();
    if (!_activeStatuses.contains(status)) {
      _setNotice('Chat is available only for your assigned active ride.',
          isError: true);
      return;
    }
    final message = _chatController.text.trim();
    if (message.isEmpty) return;
    if (message.length > 1000) {
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
      await _repository.sendRideMessage(
        rideId: rideId,
        senderId: widget.profile.id,
        message: message,
      );
      _chatController.clear();
      await _refreshRideCommunication();
      _setNotice('Message saved to this ride chat.');
    } catch (error) {
      _setNotice('Message was not sent: $error', isError: true);
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _callPassenger() async {
    final phone = (_passengerDetails?['passenger_phone'] ??
            _passengerDetails?['phone'] ??
            _passengerDetails?['phone_number'] ??
            '')
        .toString()
        .replaceAll(RegExp(r'[^+0-9]'), '');
    if (phone.isEmpty) {
      _setNotice('Passenger phone number is not available.', isError: true);
      return;
    }
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!opened) throw StateError('The phone dialer could not be opened.');
    } catch (error) {
      _setNotice('Could not open the phone dialer: $error', isError: true);
    }
  }

  Widget _rideCommunicationCard(Map<String, dynamic> ride) {
    final theme = Theme.of(context);
    final details = _passengerDetails ?? const <String, dynamic>{};
    final passengerName =
        (details['passenger_name'] ?? details['full_name'] ?? 'Passenger')
            .toString();
    final phone = (details['passenger_phone'] ??
            details['phone'] ??
            details['phone_number'] ??
            '')
        .toString();
    final status = (ride['status'] ?? '').toString().toLowerCase();
    final chatAvailable = _activeStatuses.contains(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_passengerDetails != null)
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned passenger',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(passengerName),
                  if (phone.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _callPassenger,
                        icon: const Icon(Icons.call),
                        label: const Text('Call passenger'),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          Text(
            'Passenger contact is not available from the ride-details service.',
            style: theme.textTheme.bodySmall,
          ),
        if (status == 'accepted' ||
            status == 'arriving' ||
            status == 'started') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            child: RrydTripMap(
              pickup: _pickupPoint,
              destination: _destinationPoint,
              passengerLocation: _passengerPoint,
              driverLocation: _driverPoint,
              applicationId: 'com.rryd.driver',
              driverRoute: _routeToPassenger,
              showCurrentMapPinHint: false,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _communicationStatus,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Text(
            'Ride chat',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
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
                      final mine = message['sender_id'].toString() ==
                          widget.profile.id;
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
                          child: Text(
                            (message['message'] ?? '').toString(),
                          ),
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
                  decoration: InputDecoration(
                    labelText: 'Message passenger',
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
            'Chat is restricted by Supabase ride_messages policies. '
            'Only messages confirmed by Supabase are shown.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _acceptRide(Map<String, dynamic> ride) async {
    final type = (ride['vehicle_type'] ?? '').toString();
    if (!_online ||
        !widget.profile.isVerified ||
        widget.profile.isSuspended) {
      _setNotice('You are not currently eligible to accept rides.',
          isError: true);
      return;
    }
    if (!_approvedVehicleTypes.contains(type)) {
      _setNotice(
        'You need an admin-approved $type vehicle to accept this request.',
        isError: true,
      );
      return;
    }
    if (_activeRide != null) {
      _setNotice(
        'Finish your current ride before accepting another request.',
        isError: true,
      );
      return;
    }
    final id = int.tryParse(ride['id'].toString());
    if (id == null) {
      _setNotice('Ride ID is not in the expected format.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await _repository.acceptRide(id);
      await _loadData();
      _setNotice('Ride acceptance was confirmed by Rryd.');
    } catch (error) {
      _setNotice('Ride was not accepted: $error', isError: true);
      await _loadData();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _performRideAction(String action) async {
    final ride = _activeRide;
    if (ride == null) return;
    final id = int.tryParse(ride['id'].toString());
    if (id == null) {
      _setNotice('Ride ID is not in the expected format.', isError: true);
      return;
    }
    final labels = {
      'driver_arriving': 'Mark yourself as arriving?',
      'start_ride': 'Start this passenger trip?',
      'complete_ride': 'Confirm this ride is complete?',
      'cancel_ride': 'Cancel this ride?',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(RrydStrings.of(context).text('confirm_ride_action')),
        content: Text(labels[action] ?? 'Continue?'),
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

    setState(() => _busy = true);
    try {
      await _repository.runRideAction(action: action, rideId: id);
      await _loadData();
      _setNotice('Rryd confirmed the ride update.');
    } catch (error) {
      _setNotice('Ride update was not confirmed: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RrydStrings.of(context);
    final theme = Theme.of(context);
    final completed = _completedRides;
    final cancelledCount = _myRides
        .where((r) => (r['status'] ?? '').toString().toLowerCase() == 'cancelled')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rryd Driver'),
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
            onPressed: _showDriverSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: strings.text('sign_out'),
            onPressed: () async {
              if (_online) {
                try {
                  await _repository.setOnline(false);
                } catch (_) {
                  // Sign-out continues even if the offline RPC is unavailable.
                }
              }
              await _locationSubscription?.cancel();
              await RrydAuthService().signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    '${strings.text('welcome')}, '
                    '${widget.profile.fullName.isEmpty ? 'Driver' : widget.profile.fullName}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _online ? strings.text('online') : strings.text('offline'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: _online
                                        ? const Color(0xFF16B981)
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Icon(
                                _online
                                    ? Icons.wifi_tethering
                                    : Icons.wifi_tethering_off,
                                color: _online
                                    ? const Color(0xFF16B981)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.profile.isVerified
                                ? strings.text('driver_approved')
                                : strings.text('driver_pending_label'),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _gpsStatus.isEmpty
                                ? strings.text('location_not_requested')
                                : _gpsStatus,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _busy ? null : _toggleOnline,
                            icon: Icon(
                              _online ? Icons.pause_circle : Icons.play_circle,
                            ),
                            label: Text(_online ? strings.text('go_offline') : strings.text('go_online')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 10),
                    _noticeCard(_notice!, _noticeIsError),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    strings.text('my_vehicles'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_vehicles.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          strings.text('no_vehicles'),
                        ),
                      ),
                    )
                  else
                    ..._vehicles.map(_vehicleCard),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _vehicleFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              strings.text('register_vehicle'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.text('vehicle_review_text'),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _newVehicleType,
                              decoration: InputDecoration(
                                labelText: strings.text('vehicle_type'),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'bike', child: Text('Bike')),
                                DropdownMenuItem(value: 'car', child: Text('Car')),
                                DropdownMenuItem(value: 'tuk_tuk', child: Text('Tuk Tuk')),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() => _newVehicleType = value);
                                      }
                                    },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _vehicleModelController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: strings.text('vehicle_model'),
                                prefixIcon: Icon(Icons.directions_car_outlined),
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().length < 2)
                                      ? 'Enter the vehicle model.'
                                      : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _vehicleNumberController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: strings.text('vehicle_number'),
                                prefixIcon: Icon(Icons.confirmation_number_outlined),
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().length < 3)
                                      ? 'Enter the vehicle registration number.'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy ? null : _submitVehicle,
                              icon: const Icon(Icons.add_road),
                              label: Text(strings.text('submit_vehicle')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.text('earnings_overview'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          strings.text('driver_net'),
                          _money(_sumField(completed, 'driver_earnings')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metricCard(
                          strings.text('company_commission'),
                          _money(_sumField(completed, 'admin_earnings')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(strings.text('completed'), '${completed.length}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metricCard(strings.text('cancelled'), '$cancelledCount'),
                      ),
                    ],
                  ),
                  if (_activeRide != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      strings.text('current_ride'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _activeRideCard(_activeRide!),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.text('incoming_requests'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.text('refresh'),
                        onPressed: _busy ? null : () => _loadData(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (!_online)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          strings.text('go_online_requests'),
                        ),
                      ),
                    )
                  else if (_requestReadFailed)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          strings.text('requests_unavailable'),
                        ),
                      ),
                    )
                  else if (_requests.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(strings.text('no_requests')),
                      ),
                    )
                  else
                    ..._requests.map(_requestCard),
                  const SizedBox(height: 18),
                  Text(
                    strings.text('recent_rides'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._myRides.take(10).map(_historyCard),
                ],
              ),
            ),
    );
  }

  Widget _noticeCard(String text, bool isError) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? theme.colorScheme.error : theme.colorScheme.primary)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> vehicle) {
    final strings = RrydStrings.of(context);
    final type = (vehicle['vehicle_type'] ?? 'Vehicle').toString();
    final model = (vehicle['vehicle_model'] ?? type).toString();
    final number = (vehicle['vehicle_number'] ?? 'Number not listed').toString();
    final approved = vehicle['is_approved'] == true;
    return Card(
      child: ListTile(
        leading: Icon(
          type == 'car'
              ? Icons.directions_car
              : type == 'tuk_tuk'
                  ? Icons.electric_rickshaw
                  : Icons.two_wheeler,
          color: RrydTheme.orange,
        ),
        title: Text(model),
        subtitle: Text('$type · $number'),
        trailing: Chip(
          label: Text(approved ? strings.text('approved') : strings.text('pending')),
          backgroundColor: approved
              ? const Color(0xFF16B981).withValues(alpha: 0.12)
              : null,
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
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

  Widget _requestCard(Map<String, dynamic> ride) {
    final strings = RrydStrings.of(context);
    final type = (ride['vehicle_type'] ?? '').toString();
    final compatible = _approvedVehicleTypes.contains(type);
    final fare = ride['estimated_fare'] ?? ride['fare'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ride['pickup_location'] ?? 'Pickup'} → '
              '${ride['destination'] ?? 'Destination'}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${type.toUpperCase()} · Ride #${ride['id']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (fare != null) ...[
              const SizedBox(height: 5),
              Text(
                strings.text('passenger_estimate') + ': ${_money((fare as num).toDouble())}',
                style: const TextStyle(
                  color: Color(0xFF16B981),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy || !compatible || _activeRide != null
                  ? null
                  : () => _acceptRide(ride),
              child: Text(
                compatible
                    ? strings.text('accept_ride')
                    : 'Requires approved $type vehicle',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeRideCard(Map<String, dynamic> ride) {
    final strings = RrydStrings.of(context);
    final status = (ride['status'] ?? '').toString().toLowerCase();
    String? nextAction;
    String? actionLabel;
    if (status == 'accepted') {
      nextAction = 'driver_arriving';
      actionLabel = strings.text('mark_arriving');
    } else if (status == 'arriving') {
      nextAction = 'start_ride';
      actionLabel = strings.text('start_ride');
    } else if (status == 'started') {
      nextAction = 'complete_ride';
      actionLabel = strings.text('complete_ride');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(status.toUpperCase())),
            const SizedBox(height: 8),
            Text(
              '${ride['pickup_location'] ?? 'Pickup'} → '
              '${ride['destination'] ?? 'Destination'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Ride #${ride['id']}'),
            const SizedBox(height: 12),
            if (nextAction != null)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _performRideAction(nextAction!),
                child: Text(actionLabel!),
              ),
            OutlinedButton(
              onPressed:
                  _busy ? null : () => _performRideAction('cancel_ride'),
              child: const Text('Cancel ride'),
            ),
            const SizedBox(height: 12),
            _rideCommunicationCard(ride),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> ride) {
    final fare = ride['final_fare'] ?? ride['fare'];
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.route_outlined),
        title: Text(
          '${ride['pickup_location'] ?? 'Pickup'} → '
          '${ride['destination'] ?? 'Destination'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Ride #${ride['id']} · ${ride['status'] ?? 'Unknown'}',
        ),
        trailing: fare == null
            ? null
            : Text(_money((fare as num).toDouble())),
      ),
    );
  }

  String _money(double value) => 'NPR ${value.round()}';
}
