import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'analytics_service.dart';
import 'saved_parks_provider.dart';
import 'notification_service.dart';

/// Turn this ON only when you want an accessibility screenshot.
const bool kShowSemanticsDebugger = false;

/// TEMP for DevTools evidence:
/// - true for "BEFORE" screenshot (intentionally slower)
/// - false for "AFTER" screenshot (optimised)
const bool kDevtoolsSlowMode = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('saved_parks');

  // Firebase init (safe-wrapped so Windows doesn't break if anything is off)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  await AnalyticsService.instance.init();

  // Notifications only on Android/iOS
  if (Platform.isAndroid || Platform.isIOS) {
    await NotificationService.instance.init();
  }

  runApp(const ProviderScope(child: AppRoot()));
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return const CupertinoApp(
        debugShowCheckedModeBanner: false,
        showSemanticsDebugger: kShowSemanticsDebugger,
        home: NearbyParksScreen(isCupertino: true),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      showSemanticsDebugger: kShowSemanticsDebugger,
      theme: ThemeData(useMaterial3: true),
      home: const NearbyParksScreen(isCupertino: false),
    );
  }
}

class NearbyParksScreen extends ConsumerWidget {
  final bool isCupertino;
  const NearbyParksScreen({super.key, required this.isCupertino});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedCount = ref.watch(savedParksProvider).length;

    Future<void> openSaved() async {
      await AnalyticsService.instance.logEvent(
        'open_saved_parks',
        parameters: {'saved_count': savedCount},
      );

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SavedParksScreen()),
      );
    }

    final openSavedLabel = "Open saved parks. $savedCount saved.";

    if (isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('ParkPal'),
          trailing: Semantics(
            label: openSavedLabel,
            button: true,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: openSaved,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.heart),
                  const SizedBox(width: 6),
                  Text('$savedCount'),
                ],
              ),
            ),
          ),
        ),
        child: SafeArea(child: NearbyParksBody(isCupertino: isCupertino)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkPal'),
        actions: [
          Semantics(
            label: openSavedLabel,
            button: true,
            child: IconButton(
              tooltip: "Saved parks ($savedCount)",
              onPressed: openSaved,
              icon: Badge(
                label: Text('$savedCount'),
                child: const Icon(Icons.favorite),
              ),
            ),
          ),
        ],
      ),
      body: NearbyParksBody(isCupertino: isCupertino),
    );
  }
}

class NearbyParksBody extends StatefulWidget {
  final bool isCupertino;
  const NearbyParksBody({super.key, required this.isCupertino});

  @override
  State<NearbyParksBody> createState() => _NearbyParksBodyState();
}

class _NearbyParksBodyState extends State<NearbyParksBody> {
  Position? _pos;
  String? _error;
  bool _loading = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  Map<String, double> _distanceCacheKm = {};
  List<Park> _sortedParks = [];

  final List<Park> _parks = const [
    Park(name: "Argotti Gardens", lat: 35.8969, lng: 14.5065),
    Park(name: "Upper Barrakka Gardens", lat: 35.8964, lng: 14.5136),
    Park(name: "St. Philip's Garden", lat: 35.9006, lng: 14.5146),
  ];

  @override
  void initState() {
    super.initState();
    _sortedParks = [..._parks];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _recomputeDistancesAndSort() {
    if (_pos == null) {
      _distanceCacheKm = {};
      _sortedParks = [..._parks];
      return;
    }

    final cache = <String, double>{};
    for (final p in _parks) {
      final meters = Geolocator.distanceBetween(
        _pos!.latitude,
        _pos!.longitude,
        p.lat,
        p.lng,
      );
      cache[p.id] = meters / 1000.0;
    }

    final sorted = [..._parks]
      ..sort((a, b) => (cache[a.id] ?? double.infinity)
          .compareTo(cache[b.id] ?? double.infinity));

    _distanceCacheKm = cache;
    _sortedParks = sorted;
  }

  Future<void> _getLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await AnalyticsService.instance.logEvent('use_my_location_tapped');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled. Turn them on and retry.");
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permission permanently denied. Enable it in settings.");
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _pos = pos;
        _recomputeDistancesAndSort();
      });

      await AnalyticsService.instance.logEvent('location_obtained');
    } catch (e) {
      setState(() => _error = e.toString());
      await AnalyticsService.instance.logEvent(
        'location_error',
        parameters: {'message': e.toString()},
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openDetails(BuildContext context, Park p) async {
    await AnalyticsService.instance.logEvent(
      'view_park_details',
      parameters: {'park_id': p.id, 'park_name': p.name},
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ParkDetailsScreen(park: p, userPos: _pos)),
    );
  }

  double _distanceKmSlow(Park p) {
    if (_pos == null) return double.infinity;
    final meters = Geolocator.distanceBetween(
      _pos!.latitude,
      _pos!.longitude,
      p.lat,
      p.lng,
    );
    return meters / 1000.0;
  }

  @override
  Widget build(BuildContext context) {
    final notificationsSupported = NotificationService.instance.supported;

    final baseList = (() {
      if (kDevtoolsSlowMode && _pos != null) {
        final temp = [..._parks]
          ..sort((a, b) {
            final da = Geolocator.distanceBetween(
                  _pos!.latitude,
                  _pos!.longitude,
                  a.lat,
                  a.lng,
                ) /
                1000.0;
            final db = Geolocator.distanceBetween(
                  _pos!.latitude,
                  _pos!.longitude,
                  b.lat,
                  b.lng,
                ) /
                1000.0;
            return da.compareTo(db);
          });
        return temp;
      }
      return (_pos == null) ? _parks : _sortedParks;
    })();

    final filtered = _query.isEmpty
        ? baseList
        : baseList.where((p) => p.name.toLowerCase().contains(_query)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: "Search parks",
            hintText: "e.g., Barrakka",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        Semantics(
          label: "Use my location",
          button: true,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_loading ? "Getting location..." : "Use my location"),
          ),
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: notificationsSupported
              ? () => NotificationService.instance.showTestIn5Seconds()
              : null,
          icon: const Icon(Icons.notifications_active),
          label: Text(
            notificationsSupported
                ? "Test notification (5s)"
                : "Notifications: run on Android/iOS",
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: notificationsSupported ? () => NotificationService.instance.cancelAll() : null,
            child: const Text("Cancel notifications"),
          ),
        ),

        const SizedBox(height: 12),

        if (_pos != null)
          Card(
            child: ListTile(
              title: const Text("Your location"),
              subtitle: Text(
                "${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}",
              ),
            ),
          ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),

        const SizedBox(height: 16),
        const Text(
          "Nearby parks",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        for (final p in filtered)
          Consumer(
            builder: (context, ref, _) {
              final saved = ref.watch(savedParksProvider).containsKey(p.id);

              final distanceText = _pos == null
                  ? "Tap 'Use my location' to calculate distance"
                  : (kDevtoolsSlowMode
                      ? "${_distanceKmSlow(p).toStringAsFixed(2)} km away"
                      : "${(_distanceCacheKm[p.id] ?? 0).toStringAsFixed(2)} km away");

              final saveLabel = saved ? "Remove ${p.name} from saved parks" : "Save ${p.name}";

              return Card(
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text(distanceText),
                  trailing: Semantics(
                    label: saveLabel,
                    button: true,
                    child: IconButton(
                      tooltip: saved ? "Unsave" : "Save",
                      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_add_outlined),
                      onPressed: () async {
                        final willSave = !saved;

                        ref.read(savedParksProvider.notifier).toggleSave(p);

                        await AnalyticsService.instance.logEvent(
                          'toggle_save_park',
                          parameters: {
                            'park_id': p.id,
                            'park_name': p.name,
                            'saved': willSave,
                          },
                        );
                      },
                    ),
                  ),
                  onTap: () => _openDetails(context, p),
                ),
              );
            },
          ),
      ],
    );
  }
}

class ParkDetailsScreen extends ConsumerStatefulWidget {
  final Park park;
  final Position? userPos;
  const ParkDetailsScreen({super.key, required this.park, required this.userPos});

  @override
  ConsumerState<ParkDetailsScreen> createState() => _ParkDetailsScreenState();
}

class _ParkDetailsScreenState extends ConsumerState<ParkDetailsScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(savedParksProvider.notifier).getSaved(widget.park.id);
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedMap = ref.watch(savedParksProvider);
    final isSaved = savedMap.containsKey(widget.park.id);

    return Scaffold(
      appBar: AppBar(title: Text(widget.park.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.park.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Coordinates: ${widget.park.lat}, ${widget.park.lng}"),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: "Notes",
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (v) {
                    if (isSaved) {
                      ref.read(savedParksProvider.notifier).updateNote(widget.park.id, v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final willSave = !isSaved;

                    await ref.read(savedParksProvider.notifier).toggleSave(
                          widget.park,
                          noteIfSaving: _noteController.text.trim(),
                        );

                    await AnalyticsService.instance.logEvent(
                      'toggle_save_from_details',
                      parameters: {
                        'park_id': widget.park.id,
                        'park_name': widget.park.name,
                        'saved': willSave,
                      },
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isSaved ? "Removed from saved" : "Saved park")),
                    );
                  },
                  icon: Icon(isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
                  label: Text(isSaved ? "Unsave park" : "Save park"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SavedParksScreen extends ConsumerWidget {
  const SavedParksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedParksProvider).values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return Scaffold(
      appBar: AppBar(title: const Text("Saved parks")),
      body: saved.isEmpty
          ? const Center(child: Text("No saved parks yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              itemBuilder: (context, i) {
                final sp = saved[i];
                return Card(
                  child: ListTile(
                    title: Text(sp.name),
                    subtitle: Text(sp.note.isEmpty ? "No notes" : sp.note),
                    trailing: IconButton(
                      tooltip: "Remove",
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        ref.read(savedParksProvider.notifier).toggleSave(
                              Park(name: sp.name, lat: sp.lat, lng: sp.lng),
                            );

                        await AnalyticsService.instance.logEvent(
                          'remove_saved_park',
                          parameters: {'park_id': sp.id, 'park_name': sp.name},
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
