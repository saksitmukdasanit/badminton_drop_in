import 'package:badminton/shared/booking_details_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

double? _parseCoord(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool _hasValidCoords(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat.abs() < 1e-7 && lng.abs() < 1e-7) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/// แผนที่หาก๊วน (tiles: OpenStreetMap) — markers จาก `latitude`/`longitude` ในข้อมูลการ์ด
class SearchSessionsMapView extends StatefulWidget {
  const SearchSessionsMapView({
    super.key,
    required this.games,
    this.isLoadingOverlay = false,
  });

  final List<dynamic> games;
  final bool isLoadingOverlay;

  @override
  State<SearchSessionsMapView> createState() => _SearchSessionsMapViewState();
}

class _SearchSessionsMapViewState extends State<SearchSessionsMapView> {
  final MapController _mapController = MapController();

  static final LatLng _bangkok = LatLng(13.7563, 100.5018);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchSessionsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.games != widget.games) {
      _scheduleFit();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleFit());
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pts = _distinctPoints();
      if (pts.isEmpty) {
        _mapController.move(_bangkok, 11);
        return;
      }
      if (pts.length == 1) {
        _mapController.move(pts.first, 14);
        return;
      }
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    });
  }

  List<LatLng> _distinctPoints() {
    final seen = <String, LatLng>{};
    for (final raw in widget.games) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final lat = _parseCoord(m['latitude']);
      final lng = _parseCoord(m['longitude']);
      if (!_hasValidCoords(lat, lng)) continue;
      final key = '${lat!.toStringAsFixed(5)}_${lng!.toStringAsFixed(5)}';
      seen[key] = LatLng(lat, lng);
    }
    return seen.values.toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByCoordinate() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final raw in widget.games) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final lat = _parseCoord(m['latitude']);
      final lng = _parseCoord(m['longitude']);
      if (!_hasValidCoords(lat, lng)) continue;
      final key = '${lat!.toStringAsFixed(5)}_${lng!.toStringAsFixed(5)}';
      map.putIfAbsent(key, () => []).add(m);
    }
    return map;
  }

  Future<void> _centerOnUser() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่ได้รับสิทธิ์ตำแหน่ง')),
        );
      }
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
  }

  void _openClusterSheet(List<Map<String, dynamic>> sessions) {
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                sessions.length > 1
                    ? 'ก๊วนในจุดนี้ (${sessions.length})'
                    : 'รายละเอียดก๊วน',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...sessions.map((g) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.15),
                  child: Icon(Icons.sports_tennis, color: primary),
                ),
                title: Text(g['groupName']?.toString() ?? 'ก๊วน'),
                subtitle: Text(
                  '${g['courtName'] ?? '-'} • ${g['sessionDate'] ?? ''} ${g['startTime'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final details = bookingDetailsFromUpcomingCardMap(g);
                  context.push('/booking-confirm', extra: details);
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final clusters = _groupByCoordinate();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _bangkok,
            initialZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dropinbad.badminton',
            ),
            MarkerLayer(
              markers: [
                for (final e in clusters.entries)
                  Marker(
                    point: LatLng(
                      _parseCoord(e.value.first['latitude'])!,
                      _parseCoord(e.value.first['longitude'])!,
                    ),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _openClusterSheet(e.value),
                      child: CircleAvatar(
                        backgroundColor: primary,
                        child: Text(
                          '${e.value.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              alignment: Alignment.bottomRight,
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        if (clusters.isEmpty && !widget.isLoadingOverlay)
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ไม่มีก๊วนในผลค้นหานี้ที่มีพิกัดสนาม\n'
                  '(สนามเก่าอาจยังไม่ได้บันทึก lat/long)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        if (widget.isLoadingOverlay)
          const LinearProgressIndicator(minHeight: 3),
        Positioned(
          right: 12,
          bottom: 24,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'search_map_fit',
                onPressed: _scheduleFit,
                child: const Icon(Icons.fit_screen),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'search_map_me',
                onPressed: _centerOnUser,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
