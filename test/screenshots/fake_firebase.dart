// In-memory stand-ins for Firebase, installed at the platform-interface level.
//
// The app talks to Firebase directly in several places
// (`FirebaseAuth.instance.currentUser`, `DatabaseService(uid: …)` streams), so
// instead of adding seams to every screen the screenshot tests swap the
// platform implementations underneath `firebase_auth` and `cloud_firestore`.
// The app's own code — DatabaseService queries, model parsing, providers —
// runs unchanged against the data seeded here.
//
// Only what the app actually uses is implemented: collection/doc paths,
// `where(isEqualTo)`, `orderBy`, `limit`, `get`, `snapshots`, `set`
// (incl. merge), `update`, `delete` and batches. Snapshots emit the current
// contents once; writes are stored but not pushed to open listeners.

// The platform interfaces are transitive dependencies of firebase_core,
// firebase_auth and cloud_firestore; they are deliberately not listed in
// pubspec.yaml just for this harness.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// Installs the fakes and initialises a default Firebase app. Call once from
/// `setUpAll` (it needs a real async zone, not `testWidgets`' fake one).
Future<FakeFirestore> installFakeFirebase({
  required String uid,
  String? email,
  String? displayName,
}) async {
  setupFirebaseCoreMocks();
  final auth = FakeFirebaseAuth()
    ..signIn(uid: uid, email: email, displayName: displayName);
  FirebaseAuthPlatform.instance = auth;
  final firestore = FakeFirestore();
  FirebaseFirestorePlatform.instance = firestore;
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  return firestore;
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class FakeFirebaseAuth extends FirebaseAuthPlatform {
  FakeFirebaseAuth() : super();

  UserPlatform? _user;

  void signIn({required String uid, String? email, String? displayName}) {
    _user = _FakeUser(
      this,
      PigeonUserDetails(
        userInfo: PigeonUserInfo(
          uid: uid,
          email: email,
          displayName: displayName,
          isAnonymous: false,
          isEmailVerified: true,
          creationTimestamp:
              DateTime.now().subtract(const Duration(days: 400)).millisecondsSinceEpoch,
          lastSignInTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
        providerData: const [],
      ),
    );
  }

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => _user;

  @override
  set currentUser(UserPlatform? userPlatform) => _user = userPlatform;

  @override
  String? get languageCode => 'en';

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(_user);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(_user);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(_user);

  @override
  Future<void> signOut() async => _user = null;
}

class _FakeUser extends UserPlatform {
  _FakeUser(FirebaseAuthPlatform auth, PigeonUserDetails details)
      : super(auth, _FakeMultiFactor(auth), details);
}

class _FakeMultiFactor extends MultiFactorPlatform {
  _FakeMultiFactor(super.auth);
}

// ---------------------------------------------------------------------------
// Firestore
// ---------------------------------------------------------------------------

class FakeFirestore extends FirebaseFirestorePlatform {
  FakeFirestore() : super();

  /// Document path → data. Paths look like `users/<uid>/workout_programs/<id>`.
  final Map<String, Map<String, dynamic>> documents = {};

  final math.Random _random = math.Random(7);

  /// Stores [data] at [path], converting `DateTime`s to `Timestamp`s the way
  /// the real SDK does on the wire.
  void seed(String path, Map<String, dynamic> data) {
    documents[path] = _normalise(data) as Map<String, dynamic>;
  }

  String autoId() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) =>
      this;

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _FakeCollection(this, collectionPath);

  @override
  DocumentReferencePlatform doc(String documentPath) =>
      _FakeDocument(this, documentPath);

  @override
  WriteBatchPlatform batch() => _FakeBatch(this);

  // --- query evaluation ----------------------------------------------------

  List<DocumentSnapshotPlatform> _run(
    String collectionPath,
    Map<String, dynamic> parameters,
  ) {
    final prefix = '$collectionPath/';
    var entries = documents.entries
        .where((e) =>
            e.key.startsWith(prefix) &&
            !e.key.substring(prefix.length).contains('/'))
        .toList();

    for (final condition
        in (parameters['where'] as List?)?.cast<List<dynamic>>() ??
            const <List<dynamic>>[]) {
      final field = _fieldName(condition[0]);
      final op = condition[1] as String;
      final value = condition[2];
      entries = entries.where((e) {
        final actual = e.value[field];
        switch (op) {
          case '==':
            return actual == value;
          case '!=':
            return actual != value;
          default:
            return true; // Not needed by the app.
        }
      }).toList();
    }

    final orders = (parameters['orderBy'] as List?)?.cast<List<dynamic>>() ??
        const <List<dynamic>>[];
    if (orders.isNotEmpty) {
      entries.sort((a, b) {
        for (final order in orders) {
          final field = _fieldName(order[0]);
          final descending = order[1] == true;
          final c = _compare(a.value[field], b.value[field]);
          if (c != 0) return descending ? -c : c;
        }
        return 0;
      });
    }

    final limit = parameters['limit'];
    if (limit is int && entries.length > limit) {
      entries = entries.sublist(0, limit);
    }

    return [for (final e in entries) _snapshot(e.key, e.value)];
  }

  DocumentSnapshotPlatform _snapshot(String path, Map<String, dynamic>? data) {
    return DocumentSnapshotPlatform(
      this,
      path,
      data == null ? null : Map<String, dynamic>.from(data),
      PigeonSnapshotMetadata(hasPendingWrites: false, isFromCache: false),
    );
  }

  QuerySnapshotPlatform _querySnapshot(
    String collectionPath,
    Map<String, dynamic> parameters,
  ) {
    return QuerySnapshotPlatform(
      _run(collectionPath, parameters),
      const <DocumentChangePlatform>[],
      SnapshotMetadataPlatform(false, false),
    );
  }

  void _set(String path, Map<String, dynamic> data, SetOptions? options) {
    final normalised = _normalise(data) as Map<String, dynamic>;
    if (options?.merge == true && documents.containsKey(path)) {
      documents[path] = {...documents[path]!, ...normalised};
    } else {
      documents[path] = normalised;
    }
  }

  void _update(String path, Map<FieldPath, dynamic> data) {
    final existing = documents[path];
    if (existing == null) return;
    for (final entry in data.entries) {
      existing[entry.key.components.join('.')] = _normalise(entry.value);
    }
  }

  static String _fieldName(Object? field) {
    if (field is FieldPath) return field.components.join('.');
    return field.toString();
  }

  static int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is Timestamp && b is Timestamp) return a.compareTo(b);
    if (a is num && b is num) return a.compareTo(b);
    if (a is String && b is String) return a.compareTo(b);
    return 0;
  }

  static Object? _normalise(Object? value) {
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) e.key.toString(): _normalise(e.value),
      };
    }
    if (value is List) return value.map(_normalise).toList();
    if (value is FieldValuePlatform) return Timestamp.now();
    return value;
  }
}

/// Emits [build]'s result once to every listener, like a Firestore listener
/// that never sees another change.
Stream<T> _once<T>(T Function() build) {
  return Stream<T>.multi((controller) {
    controller.add(build());
  });
}

mixin _QueryOps on QueryPlatform {
  FakeFirestore get _store => firestore as FakeFirestore;
  String get _collectionPath;

  QueryPlatform _with(String key, Object? value) =>
      _FakeQuery(_store, _collectionPath, {...parameters, key: value});

  @override
  QueryPlatform where(List<List<dynamic>> conditions) =>
      _with('where', conditions);

  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) =>
      _with('orderBy', orders.toList());

  @override
  QueryPlatform limit(int limit) => _with('limit', limit);

  @override
  Future<QuerySnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async =>
      _store._querySnapshot(_collectionPath, parameters);

  @override
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) =>
      _once(() => _store._querySnapshot(_collectionPath, parameters));
}

class _FakeQuery extends QueryPlatform with _QueryOps {
  _FakeQuery(FakeFirestore store, this._collectionPath, Map<String, dynamic> params)
      : super(store, params);

  @override
  final String _collectionPath;
}

/// The modifiers of an unfiltered query — `cloud_firestore` reads and
/// extends these lists, so a collection must start with them.
final Map<String, dynamic> _defaultParameters = Map.unmodifiable({
  'where': const <List<dynamic>>[],
  'orderBy': const <List<dynamic>>[],
  'startAt': null,
  'startAfter': null,
  'endAt': null,
  'endBefore': null,
  'limit': null,
  'limitToLast': null,
});

class _FakeCollection extends CollectionReferencePlatform with _QueryOps {
  _FakeCollection(FakeFirestore super.store, super.path);

  @override
  Map<String, dynamic> get parameters => _defaultParameters;

  @override
  String get _collectionPath => path;

  @override
  DocumentReferencePlatform doc([String? path]) =>
      _FakeDocument(_store, '${this.path}/${path ?? _store.autoId()}');
}

class _FakeDocument extends DocumentReferencePlatform {
  _FakeDocument(FakeFirestore super.store, super.path);

  FakeFirestore get _store => firestore as FakeFirestore;

  @override
  Future<DocumentSnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async =>
      _store._snapshot(path, _store.documents[path]);

  @override
  Stream<DocumentSnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) =>
      _once(() => _store._snapshot(path, _store.documents[path]));

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async =>
      _store._set(path, data, options);

  @override
  Future<void> update(Map<FieldPath, dynamic> data) async =>
      _store._update(path, data);

  @override
  Future<void> delete() async => _store.documents.remove(path);
}

class _FakeBatch extends WriteBatchPlatform {
  _FakeBatch(this._store) : super();

  final FakeFirestore _store;
  final List<void Function()> _ops = [];

  @override
  Future<void> commit() async {
    for (final op in _ops) {
      op();
    }
    _ops.clear();
  }

  @override
  void delete(String documentPath) =>
      _ops.add(() => _store.documents.remove(documentPath));

  @override
  void set(
    String documentPath,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) =>
      _ops.add(() => _store._set(documentPath, data, options));

  @override
  void update(String documentPath, Map<String, dynamic> data) => _ops.add(
        () => _store._update(documentPath, {
          for (final e in data.entries) FieldPath.fromString(e.key): e.value,
        }),
      );
}
