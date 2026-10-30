import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rryd_core/rryd_core.dart';

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
  final _vehicleFormKey = GlobalKey<FormState>();
  final _vehicleModelController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final Set<String> _knownRequestIds = {};
  String _newVehicleType = 'bike';
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _myRides = [];
  List<Map<String, dynamic>> _requests = [];
  StreamSubscription<Position>? _locationSubscription;
  Timer? _pollTimer;
  DateTime? _lastLocationWrite;
  bool _online = false;
  bool _loading = true;
  bool _busy = false;
  bool _hasInitialRequestSnapshot = false;
  bool _requestReadFailed = false;
  String? _notice;
  bool _noticeIsError = false;
  String _gpsStatus = strings.text('location_not_requested');

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
      if (!mounted || !_online) return;
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
      if (goingOnline) position = await _getCurrentPosition();
      await _repository.setOnline(goingOnline);
      if (!mounted) return;
      setState(() {
        _online = goingOnline;
        _gpsStatus = goingOnline
            ? 'Online · sending location while the app is active'
            : 'Offline · location sharing stopped';
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
        title: const Text(strings.text('confirm_ride_action')),
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
                          Text(_gpsStatus, style: theme.textTheme.bodySmall),
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
                    const Card(
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
                              decoration: const InputDecoration(
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
                              decoration: const InputDecoration(
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
                              decoration: const InputDecoration(
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
                              label: const Text(strings.text('submit_vehicle')),
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
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          strings.text('go_online_requests'),
                        ),
                      ),
                    )
                  else if (_requestReadFailed)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          strings.text('requests_unavailable'),
                        ),
                      ),
                    )
                  else if (_requests.isEmpty)
                    const Card(
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
