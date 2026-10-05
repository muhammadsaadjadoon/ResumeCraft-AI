import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'resume.dart';

class ResumeStore extends ChangeNotifier {
  ResumeStore(this.prefs, this.cloudReady);
  final SharedPreferences prefs;
  final bool cloudReady;
  List<Resume> resumes = [];
  String? selectedId;
  String? error;
  bool dark = false;
  String? _uid;
  StreamSubscription<User?>? _auth;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cloud;
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _writes = {};
  final Set<String> _pending = {};
  int _authVersion = 0;
  bool _disposed = false;
  int get pendingCount => _pending.length;
  String get workspaceKey => _key;
  String get _key => 'resumes_${_uid ?? 'local'}';
  Resume? get selected {
    for (final r in resumes) {
      if (r.id == selectedId) {
        return r;
      }
    }
    return resumes.isEmpty ? null : resumes.first;
  }

  Future<void> init() async {
    dark = prefs.getBool('dark') ?? false;
    _load();
    if (cloudReady) {
      _auth = FirebaseAuth.instance.userChanges().listen(_accountChanged);
    }
  }

  void _load() {
    try {
      _pending
        ..clear()
        ..addAll(prefs.getStringList('pending_$_key') ?? []);
      final raw = prefs.getString(_key);
      resumes = raw == null
          ? []
          : (jsonDecode(raw) as List)
                .map(
                  (j) => Resume.fromJson(Map<String, dynamic>.from(j as Map)),
                )
                .toList();
    } catch (_) {
      resumes = [];
      error =
          'Saved data could not be read. Your previous data has not been overwritten.';
    }
    selectedId = resumes.isEmpty ? null : resumes.first.id;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _accountChanged(User? user) async {
    final version = ++_authVersion;
    final previous = _uid;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    await _cloud?.cancel();
    if (version != _authVersion) {
      return;
    }
    _uid = user?.uid;
    if (previous != _uid) {
      _load();
    }
    if (user == null) {
      return;
    }
    final owner = user.uid;
    _cloud = FirebaseFirestore.instance
        .collection('users')
        .doc(owner)
        .collection('resumes')
        .snapshots()
        .listen(
          (snapshot) {
            if (_uid != owner || snapshot.metadata.hasPendingWrites) {
              return;
            }
            // Merge newer server drafts without overwriting unsynced local edits.
            final byId = {for (final r in resumes) r.id: r};
            if (!snapshot.metadata.isFromCache) {
              final remoteIds = snapshot.docs.map((d) => d.id).toSet();
              byId.removeWhere(
                (id, r) => !remoteIds.contains(id) && !_pending.contains(id),
              );
            }
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.removed &&
                  !_pending.contains(change.doc.id)) {
                byId.remove(change.doc.id);
              }
            }
            for (final doc in snapshot.docs) {
              try {
                final r = Resume.fromJson(doc.data());
                if (!_pending.contains(r.id) &&
                    (byId[r.id] == null ||
                        r.updated.isAfter(byId[r.id]!.updated))) {
                  byId[r.id] = r;
                }
              } catch (_) {
                error =
                    'An unreadable cloud draft was skipped. Your local drafts are safe.';
              }
            }
            resumes = byId.values.toList()
              ..sort((a, b) => b.updated.compareTo(a.updated));
            if (selectedId == null && resumes.isNotEmpty) {
              selectedId = resumes.first.id;
            }
            unawaited(_persist());
            for (final r in resumes.where((r) => _pending.contains(r.id))) {
              if (!_writes.containsKey(r.id)) {
                unawaited(sync(r));
              }
            }
            if (!_disposed) {
              notifyListeners();
            }
          },
          onError: (_) {
            error =
                'Cloud sync unavailable. Drafts remain saved on this device.';
            if (!_disposed) {
              notifyListeners();
            }
          },
        );
  }

  Future<void> _persist() async {
    try {
      final key = _key;
      final pending = _pending.toList();
      final data = jsonEncode(resumes.map((r) => r.toJson()).toList());
      await prefs.setStringList('pending_$key', pending);
      await prefs.setString(key, data);
    } catch (_) {
      error =
          'Device storage is full or unavailable. Export a backup before leaving.';
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> sync(Resume r) async {
    final uid = _uid;
    if (!cloudReady || uid == null) {
      return;
    }
    final payload = r.toJson();
    final stamp = r.updated;
    final previous = _writes[r.id];
    final operation = () async {
      if (previous != null) {
        await previous;
      }
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('resumes')
            .doc(r.id)
            .set(payload);
        if (_uid == uid && r.updated == stamp) {
          _pending.remove(r.id);
          await _persist();
        }
      } catch (_) {
        if (_uid == uid) {
          error =
              'Cloud save failed. Your local draft is safe; use Retry sync.';
          if (!_disposed) {
            notifyListeners();
          }
        }
      }
    }();
    _writes[r.id] = operation;
    await operation;
    if (identical(_writes[r.id], operation)) {
      _writes.remove(r.id);
    }
  }

  void changed(Resume r) {
    if (_disposed) {
      return;
    }
    r.updated = DateTime.now();
    _pending.add(r.id);
    unawaited(_persist());

    _timers.remove(r.id)?.cancel();
    final owner = _uid;
    // Device-only drafts do not need a cloud debounce timer.
    if (cloudReady && owner != null) {
      _timers[r.id] = Timer(const Duration(milliseconds: 900), () {
        _timers.remove(r.id);
        if (!_disposed && _uid == owner) {
          unawaited(sync(r));
        }
      });
    }
    notifyListeners();
  }

  void add([Resume? item]) {
    final r = item ?? Resume.empty();
    resumes.insert(0, r);
    selectedId = r.id;
    changed(r);
  }

  void select(Resume r) {
    selectedId = r.id;
    notifyListeners();
  }

  Future<void> remove(Resume r) async {
    final owner = _uid;
    _timers.remove(r.id)?.cancel();
    await _writes[r.id];
    // Cloud deletion must succeed before local removal to avoid resurrection.
    if (cloudReady && owner != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(owner)
          .collection('resumes')
          .doc(r.id)
          .delete();
    }
    if (_uid != owner) {
      return;
    }
    _pending.remove(r.id);
    resumes.removeWhere((x) => x.id == r.id);
    selectedId = resumes.isEmpty ? null : resumes.first.id;
    await _persist();
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    dark = value;
    notifyListeners();
    await prefs.setBool('dark', value);
  }

  Future<void> retrySync() async {
    error = null;
    for (final r in resumes) {
      await sync(r);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _authVersion++;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _auth?.cancel();
    _cloud?.cancel();
    super.dispose();
  }
}
