import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class Park {
  final String name;
  final double lat;
  final double lng;

  const Park({required this.name, required this.lat, required this.lng});

  String get id => '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
}

@immutable
class SavedPark {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String note;
  final DateTime savedAt;

  const SavedPark({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.note,
    required this.savedAt,
  });

  factory SavedPark.fromPark(Park p, {String note = ''}) => SavedPark(
        id: p.id,
        name: p.name,
        lat: p.lat,
        lng: p.lng,
        note: note,
        savedAt: DateTime.now(),
      );

  SavedPark copyWith({String? note}) => SavedPark(
        id: id,
        name: name,
        lat: lat,
        lng: lng,
        note: note ?? this.note,
        savedAt: savedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'note': note,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedPark.fromJson(Map<dynamic, dynamic> json) => SavedPark(
        id: (json['id'] as String),
        name: (json['name'] as String),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        note: (json['note'] as String?) ?? '',
        savedAt: DateTime.tryParse((json['savedAt'] as String?) ?? '') ?? DateTime.now(),
      );
}

final savedParksProvider =
    NotifierProvider<SavedParksNotifier, Map<String, SavedPark>>(SavedParksNotifier.new);

class SavedParksNotifier extends Notifier<Map<String, SavedPark>> {
  late final Box _box;

  @override
  Map<String, SavedPark> build() {
    _box = Hive.box('saved_parks');

    final map = <String, SavedPark>{};
    for (final dynamic value in _box.values) {
      if (value is Map) {
        final sp = SavedPark.fromJson(value);
        map[sp.id] = sp;
      }
    }
    return map;
  }

  bool isSaved(Park p) => state.containsKey(p.id);

  SavedPark? getSaved(String parkId) => state[parkId];

  Future<void> toggleSave(Park p, {String? noteIfSaving}) async {
    final id = p.id;
    if (state.containsKey(id)) {
      await _box.delete(id);
      state = {...state}..remove(id);
      return;
    }

    final sp = SavedPark.fromPark(p, note: noteIfSaving ?? '');
    await _box.put(id, sp.toJson());
    state = {...state, id: sp};
  }

  Future<void> updateNote(String parkId, String note) async {
    final current = state[parkId];
    if (current == null) return;

    final updated = current.copyWith(note: note);
    await _box.put(parkId, updated.toJson());
    state = {...state, parkId: updated};
  }
}
