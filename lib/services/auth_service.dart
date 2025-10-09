import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Skapa en instans av FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // METOD FÖR REGISTRERING
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      // Använd FirebaseAuth för att skapa en ny användare
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Returnera användarobjektet om det lyckas
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Hantera specifika fel, t.ex. om e-posten redan används
      print('Firebase Auth Exception: ${e.message}');
      return null;
    } catch (e) {
      // Hantera alla andra typer av fel
      print('An unknown error occurred: $e');
      return null;
    }
  }

  // METOD FÖR INLOGGNING
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Använd FirebaseAuth för att logga in en befintlig användare
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Returnera användarobjektet om det lyckas
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Hantera specifika fel, t.ex. fel lösenord eller ingen användare hittades
      print('Firebase Auth Exception: ${e.message}');
      return null;
    } catch (e) {
      // Hantera alla andra typer av fel
      print('An unknown error occurred: $e');
      return null;
    }
  }

  // METOD FÖR ATT LOGGA UT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // METOD FÖR ATT RADERA KONTO
  /// Raderar det aktuella användarens Firebase Auth-konto
  /// OBS: Detta är irreversibelt!
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        print('User account deleted successfully');
      } else {
        throw Exception('No user is currently logged in');
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception during account deletion: ${e.message}');
      // Re-authentication might be needed for recent sign-in requirement
      if (e.code == 'requires-recent-login') {
        throw Exception('Account deletion requires recent authentication. Please log in again and try again.');
      }
      rethrow;
    } catch (e) {
      print('An unknown error occurred during account deletion: $e');
      rethrow;
    }
  }

  // STREAM FÖR ATT LYSSNA PÅ AUTH-ÄNDRINGAR
  // Denna är superviktig! Den talar om för appen om en användare är inloggad eller inte.
  Stream<User?> get user {
    return _auth.authStateChanges();
  }
}