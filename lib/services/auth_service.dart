import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Ett inloggningsfel formulerat för den som sitter framför skärmen.
///
/// [code] är Firebase-koden (för loggning och specialfall), [message] är det
/// som visas i UI:t.
class AuthFailure implements Exception {
  final String code;
  final String message;

  const AuthFailure(this.code, this.message);

  @override
  String toString() => message;
}

class AuthService {
  // Skapa en instans av FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Korta, mänskliga meddelanden för de Firebase-fel en användare faktiskt
  /// kan orsaka. Allt annat blir ett generiskt "försök igen".
  static String messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-disabled':
        return 'This account has been disabled.';
      // Nyare Firebase-projekt (email enumeration protection) svarar
      // 'invalid-credential' både för okänd e-post och fel lösenord.
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'requires-recent-login':
        return 'For your security, enter your password again.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this app.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  static AuthFailure _failure(FirebaseAuthException e) {
    debugPrint('Firebase Auth Exception (${e.code}): ${e.message}');
    return AuthFailure(e.code, messageFor(e.code));
  }

  // METOD FÖR REGISTRERING
  /// Kastar [AuthFailure] om registreringen misslyckas.
  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  // METOD FÖR INLOGGNING
  /// Kastar [AuthFailure] om inloggningen misslyckas.
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  // METOD FÖR ÅTERSTÄLLNING AV LÖSENORD
  /// Skickar en återställningslänk. Med email enumeration protection
  /// påslaget svarar Firebase likadant oavsett om kontot finns, så UI:t ska
  /// inte påstå att det gör det. Kastar [AuthFailure].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  // METOD FÖR ATT BEKRÄFTA LÖSENORDET IGEN
  /// Loggar in den aktuella användaren på nytt med [password]. Firebase kräver
  /// en färsk inloggning innan ett konto får raderas. Kastar [AuthFailure].
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('no-current-user', 'No account is signed in.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  // METOD FÖR ATT LOGGA UT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // METOD FÖR ATT RADERA KONTO
  /// Raderar det aktuella användarens Firebase Auth-konto.
  /// OBS: Detta är irreversibelt! Radera användarens data i Firestore FÖRST —
  /// efter det här anropet är användaren utloggad och säkerhetsreglerna
  /// släpper inte längre in någon i datan. Kastar [AuthFailure].
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('no-current-user', 'No account is signed in.');
    }
    try {
      await user.delete();
      debugPrint('User account deleted successfully');
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  // STREAM FÖR ATT LYSSNA PÅ AUTH-ÄNDRINGAR
  // Denna är superviktig! Den talar om för appen om en användare är inloggad eller inte.
  Stream<User?> get user {
    return _auth.authStateChanges();
  }
}
