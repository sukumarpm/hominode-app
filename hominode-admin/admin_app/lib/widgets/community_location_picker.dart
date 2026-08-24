import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/tenant_config.dart';
import '../services/community_location_service.dart';

class CommunityLocationPicker extends StatefulWidget {
  const CommunityLocationPicker({
    super.key,
    this.initialLocation,
    this.locationService,
    this.countryCode,
    required this.onChanged,
  });

  final CommunityLocation? initialLocation;
  final CommunityLocationGateway? locationService;
  final String? countryCode;
  final ValueChanged<CommunityLocation?> onChanged;

  @override
  State<CommunityLocationPicker> createState() =>
      _CommunityLocationPickerState();
}

class _CommunityLocationPickerState extends State<CommunityLocationPicker> {
  static const LatLng _defaultPosition = LatLng(14.5995, 120.9842);

  static const List<int> _radiusOptions = [50, 100, 150, 200, 300];

  late final CommunityLocationGateway _locationService;

  late final TextEditingController _addressController;

  GoogleMapController? _mapController;

  LatLng? _selectedPosition;
  int _radiusMeters = 150;

  bool _gettingCurrentLocation = false;
  bool _searching = false;
  String? _placeId;
  Timer? _searchDebounce;
  List<CommunityLocationSuggestion> _suggestions = const [];
  String? _searchMessage;
  int _searchGeneration = 0;
  String? _sessionToken;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialLocation;
    _locationService = widget.locationService ?? CommunityLocationService();

    _selectedPosition = initial == null
        ? null
        : LatLng(initial.latitude, initial.longitude);

    _radiusMeters = initial?.attendanceRadiusMeters ?? 150;
    _placeId = initial?.placeId;

    _addressController = TextEditingController(
      text: initial?.formattedAddress ?? '',
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapController?.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingCurrentLocation) return;

    setState(() {
      _gettingCurrentLocation = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();

      if (!mounted) return;

      final selected = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedPosition = selected;
        _placeId = null;
        _addressController.clear();
        _suggestions = const [];
        _searchMessage = null;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selected, 18),
      );

      _notifyChanged();

      final address = await _locationService.reverseGeocode(
        selected.latitude,
        selected.longitude,
      );
      if (!mounted) return;
      if (address == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No address was found for these coordinates. Enter the property address manually.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() {
        _addressController.text = address.formattedAddress;
        _placeId = address.placeId;
      });
      _notifyChanged();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingCurrentLocation = false;
        });
      }
    }
  }

  void _selectPosition(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _placeId = null;
    });

    _notifyChanged();
  }

  void _notifyChanged() {
    final selected = _selectedPosition;
    final address = _addressController.text.trim();

    if (selected == null || address.isEmpty) {
      widget.onChanged(null);
      return;
    }

    widget.onChanged(
      CommunityLocation(
        latitude: selected.latitude,
        longitude: selected.longitude,
        formattedAddress: address,
        attendanceRadiusMeters: _radiusMeters,
        placeId: _placeId,
      ),
    );
  }

  void _addressChanged(String value) {
    _placeId = null;
    _notifyChanged();
    _searchDebounce?.cancel();
    final query = value.trim();
    final generation = ++_searchGeneration;
    if (query.length < 3) {
      _sessionToken = null;
      setState(() {
        _searching = false;
        _suggestions = const [];
        _searchMessage = null;
      });
      return;
    }
    _sessionToken ??= _newSessionToken();
    setState(() {
      _suggestions = const [];
      _searchMessage = null;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _search(query, generation),
    );
  }

  Future<void> _search(String query, int generation) async {
    if (!mounted || generation != _searchGeneration) return;
    setState(() => _searching = true);
    try {
      final results = await _locationService.search(
        query,
        sessionToken: _sessionToken!,
        countryCode: widget.countryCode,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _suggestions = results;
        _searchMessage = results.isEmpty
            ? 'No matching locations found.'
            : null;
      });
    } catch (error) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _suggestions = const [];
          _searchMessage = error.toString();
        });
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _selectSuggestion(CommunityLocationSuggestion suggestion) async {
    _searchDebounce?.cancel();
    _searchGeneration++;
    setState(() {
      _searching = true;
      _searchMessage = null;
    });
    try {
      final selected = await _locationService.resolvePlace(
        suggestion.placeId,
        sessionToken: _sessionToken!,
      );
      if (!mounted) return;
      final position = LatLng(selected.latitude, selected.longitude);
      setState(() {
        _selectedPosition = position;
        _placeId = selected.placeId;
        _addressController.text = selected.formattedAddress;
        _suggestions = const [];
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(position, 18),
      );
      _notifyChanged();
    } catch (error) {
      if (mounted) setState(() => _searchMessage = error.toString());
    } finally {
      _sessionToken = null;
      if (mounted) setState(() => _searching = false);
    }
  }

  String _newSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPosition;

    final initialCamera = selected ?? _defaultPosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),

        Text(
          'Community Location',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 4),

        Text(
          'Used for security attendance and community location services.',
          style: Theme.of(context).textTheme.bodySmall,
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Property address',
            hintText: 'Search address or place name',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _addressChanged,
        ),

        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(suggestion.primaryText),
                  subtitle: suggestion.secondaryText.isEmpty
                      ? null
                      : Text(suggestion.secondaryText),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),

        if (_searchMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _searchMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _gettingCurrentLocation ? null : _useCurrentLocation,
            icon: _gettingCurrentLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _gettingCurrentLocation
                  ? 'Getting location...'
                  : 'Use Current Location',
            ),
          ),
        ),

        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 260,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCamera,
                zoom: selected == null ? 11 : 18,
              ),
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: _selectPosition,
              markers: selected == null
                  ? const {}
                  : {
                      Marker(
                        markerId: const MarkerId('community-location'),
                        position: selected,
                        draggable: true,
                        onDragEnd: _selectPosition,
                      ),
                    },
              circles: selected == null
                  ? const {}
                  : {
                      Circle(
                        circleId: const CircleId('attendance-radius'),
                        center: selected,
                        radius: _radiusMeters.toDouble(),
                        strokeWidth: 2,
                        fillColor: Colors.blue.withValues(alpha: 0.08),
                        strokeColor: Colors.blue,
                      ),
                    },
            ),
          ),
        ),

        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(
            '${selected.latitude.toStringAsFixed(6)}, '
            '${selected.longitude.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],

        const SizedBox(height: 18),

        const Text(
          'Attendance Radius',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 4),

        const Text('Security staff must be within this area to check in.'),

        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _radiusOptions.map((radius) {
            return ChoiceChip(
              label: Text('${radius}m'),
              selected: _radiusMeters == radius,
              onSelected: (_) {
                setState(() {
                  _radiusMeters = radius;
                });

                _notifyChanged();
              },
            );
          }).toList(),
        ),

        if (selected == null) ...[
          const SizedBox(height: 12),
          const Text(
            'Choose the property position on the map or use the current location.',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
