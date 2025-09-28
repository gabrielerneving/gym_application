import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Enkel state för att växla mellan Login och Register
  bool _isLogin = true; 
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers för att hämta text från textfälten
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Instans av vår kommande auth service
   final AuthService _authService = AuthService();

void _submitAuthForm() async {
  final isValid = _formKey.currentState?.validate() ?? false;
  if (!isValid) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  // Hämta e-post och lösenord från controllers
  final email = _emailController.text;
  final password = _passwordController.text;

  User? user;

  try {
    if (_isLogin) {
      user = await _authService.signInWithEmailAndPassword(email, password);
    } else {
      user = await _authService.registerWithEmailAndPassword(email, password);
    }

    // Om vi får tillbaka en användare (dvs. inloggning/registrering lyckades),
    // kommer vår app att automatiskt navigera till hemskärmen (vi fixar detta i nästa steg).
    if (user == null) {
      // Visa ett felmeddelande om något gick fel
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign you in. Please check your credentials.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    // Visa generiskt felmeddelande
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('An error occurred: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? 'Login' : 'Create Account',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // E-post fält
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Please enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Lösenord fält
                TextFormField(
                  controller: _passwordController,
                  obscureText: true, // Döljer lösenordet
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters long.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Submit-knapp
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuthForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isLogin ? 'Login' : 'Register',
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Knapp för att växla läge
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? 'Don\'t have an account? Register'
                        : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}