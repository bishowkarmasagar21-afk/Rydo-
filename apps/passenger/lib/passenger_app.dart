import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:latlong2/latlong.dart';
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

  RrydLocationPoint? _pickup;
  RrydLocationPoint? _destination;
  RrydRouteResult? _route;
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
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationService.dispose();
    super.dispose();
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

  void _clearRoute() {
    setState(() {
      _route = null;
      _availableCount = null;
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
      final fallback = RrydLocationPoint(
        label: 'Map pin ${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)}',
        latitude: point.latitude,
        longitude: point.longitude,
      );
      _setSelectedPoint(fallback);
      _setNotice(
        '${RrydStrings.of(context).text('pin_fallback')} ($error)',
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
    } catch (error) {
      _setNotice('Could not refresh your ride list: $error', isError: true);
    } finally {
      if (mounted) setState(() => _loadingRides = false);
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
                    '${widget.profile.fullName.isEmpty ? 'Passenger' : widget.profile.fullName}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
