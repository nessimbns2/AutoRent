import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/ui_helpers.dart';
import 'geocoding_service.dart';
import 'incident_map.dart';

/// Result of the picker: a point and, when found, its short address.
class PickedLocation {
  final LatLng point;
  final String? address;
  const PickedLocation(this.point, this.address);
}

/// Full-screen map to choose where an incident happened: move the map under
/// the center pin, jump to the device's position, or search an address.
/// With [readOnly] it only shows a stored position.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  final String? initialAddress;
  final bool readOnly;
  final String? title;

  const LocationPickerScreen({
    super.key,
    this.initial,
    this.initialAddress,
    this.readOnly = false,
    this.title,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  final _geo = GeocodingService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  late LatLng _center = widget.initial ?? tunisCenter;
  String? _address;
  bool _resolving = false;
  bool _moving = false;
  bool _locating = false;

  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _searchError;

  Timer? _reverseDebounce;
  Timer? _searchDebounce;
  int _reverseToken = 0;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
    _searchFocus.addListener(() => setState(() {}));
    if (!widget.readOnly && widget.initial == null) {
      // No position yet: try to start where the agent is.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _goToMyPosition(silent: true),
      );
    } else if (!widget.readOnly && widget.initialAddress == null) {
      _resolveAddress();
    }
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (widget.readOnly) return;
    _center = camera.center;
    if (hasGesture && !_moving) setState(() => _moving = true);
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _moving = false);
      _resolveAddress();
    });
  }

  Future<void> _resolveAddress() async {
    final token = ++_reverseToken;
    setState(() => _resolving = true);
    String? address;
    try {
      address = await _geo.reverse(_center);
    } catch (_) {
      address = null;
    }
    if (!mounted || token != _reverseToken) return;
    setState(() {
      _address = address;
      _resolving = false;
    });
  }

  Future<void> _goToMyPosition({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final p = await GeocodingService.currentPosition();
      if (!mounted) return;
      _map.move(p, 17);
      _center = p;
      _resolveAddress();
    } on AppException catch (e) {
      if (mounted && !silent) showSnack(context, e.message);
      if (mounted && silent) _resolveAddress();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = const [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _search(q),
    );
  }

  Future<void> _search(String q) async {
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _geo.search(q);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _searchError = results.isEmpty ? 'Aucun lieu trouvé en Tunisie.' : null;
      });
    } on AppException catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = const [];
        _searchError = e.message;
      });
    } finally {
      if (mounted && token == _searchToken) setState(() => _searching = false);
    }
  }

  void _selectResult(PlaceResult r) {
    _searchFocus.unfocus();
    _searchCtrl.text = r.name;
    _map.move(r.point, 17);
    _reverseDebounce?.cancel();
    _reverseToken++; // ignore any lookup in flight
    setState(() {
      _center = r.point;
      _address = r.name;
      _results = const [];
      _resolving = false;
    });
  }

  void _confirm() => Navigator.pop(context, PickedLocation(_center, _address));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showResults =
        _searchFocus.hasFocus &&
        (_results.isNotEmpty || _searchError != null || _searching);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.readOnly
                  ? 'Lieu de l\'incident'
                  : 'Choisir l\'emplacement'),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial != null ? 16 : 12,
              onPositionChanged: _onPositionChanged,
              onTap: (_, _) => _searchFocus.unfocus(),
            ),
            children: [
              osmTileLayer(),
              if (widget.readOnly && widget.initial != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.initial!,
                      width: 52,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: const IncidentPin(size: 52),
                    ),
                  ],
                ),
              osmAttribution(),
            ],
          ),

          // Fixed center pin (edit mode): lifts while the map moves.
          if (!widget.readOnly)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 52),
                  child: AnimatedSlide(
                    offset: Offset(0, _moving ? -0.25 : 0),
                    duration: const Duration(milliseconds: 180),
                    child: const IncidentPin(size: 52),
                  ),
                ),
              ),
            ),
          if (!widget.readOnly)
            IgnorePointer(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _moving ? 14 : 8,
                  height: _moving ? 6 : 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

          // Search bar + results.
          if (!widget.readOnly)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Material(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(26),
                    color: scheme.surface,
                    child: SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.search_rounded,
                            color: _searchFocus.hasFocus
                                ? AppColors.brand
                                : context.palette.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              textInputAction: TextInputAction.search,
                              onChanged: (v) {
                                setState(() {});
                                _onSearchChanged(v);
                              },
                              onSubmitted: _search,
                              decoration: const InputDecoration(
                                hintText: 'Rechercher une adresse, une ville…',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                          if (_searching)
                            const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Effacer',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          else
                            const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: !showResults
                        ? const SizedBox(width: double.infinity)
                        : Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 300),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: _searchError != null
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      _searchError!,
                                      style: TextStyle(
                                        color: context.palette.muted,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    itemCount: _results.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1, indent: 56),
                                    itemBuilder: (context, i) {
                                      final r = _results[i];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.place_outlined,
                                          color: AppColors.brand,
                                        ),
                                        title: Text(
                                          r.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          r.details,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () => _selectResult(r),
                                      );
                                    },
                                  ),
                          ),
                  ),
                ],
              ),
            ),

          // "Ma position" button.
          if (!widget.readOnly)
            Positioned(
              right: 16,
              bottom: 226,
              child: FloatingActionButton(
                heroTag: 'my-position',
                tooltip: 'Ma position',
                backgroundColor: scheme.surface,
                foregroundColor: AppColors.brand,
                onPressed: _locating ? null : () => _goToMyPosition(),
                child: _locating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),

          // Bottom card: address + confirm.
          Positioned(
            left: 12,
            right: 12,
            bottom: 40, // leaves room for the OpenStreetMap credit
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 6,
                shadowColor: Colors.black26,
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.place_rounded,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    _moving || _resolving
                                        ? 'Recherche de l\'adresse…'
                                        : (_address ?? 'Adresse inconnue'),
                                    key: ValueKey(
                                      '$_moving$_resolving$_address',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatLatLng(
                                    widget.readOnly && widget.initial != null
                                        ? widget.initial!
                                        : _center,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: context.palette.muted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!widget.readOnly) ...[
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: _moving ? null : _confirm,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Confirmer cet emplacement'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
