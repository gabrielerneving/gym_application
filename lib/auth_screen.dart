import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'widgets/ui/ui.dart';

/// ---------------------------------------------------------------------------
/// The first screen anybody sees: sign in, or create an account.
///
/// One card, two fields, one button. The mode switch animates rather than
/// re-laying the page out, so the screen never jumps under the finger.
/// ---------------------------------------------------------------------------
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Enkel state för att växla mellan Login och Register
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();

  // Controllers och focus nodes för textfälten
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // Instans av vår auth service
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _toggleMode() {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() => _isLogin = !_isLogin);
  }

  void _togglePasswordVisibility() {
    HapticFeedback.selectionClick();
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

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

      // Om vi får tillbaka en användare (dvs. inloggning/registrering lyckades)
      // navigerar AuthGate automatiskt vidare till appen.
      if (user == null && mounted) {
        // Visa ett felmeddelande om något gick fel
        AppSnack.show(
          context,
          ref,
          'Could not sign you in. Please check your credentials.',
          isError: true,
        );
      }
    } catch (e) {
      // Visa generiskt felmeddelande
      if (mounted) {
        AppSnack.show(context, ref, 'An error occurred: $e', isError: true);
      }
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
    final t = ref.watch(themeProvider);

    return AppPage(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FadeSlideIn(index: 0, child: _Wordmark()),
                  const SizedBox(height: AppSpacing.xxxl),
                  FadeSlideIn(index: 1, child: _buildFormCard(t)),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(index: 2, child: _buildModeSwitch(t)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(AppColors t) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwapTransitionBox(
                value: _isLogin,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLogin ? 'Welcome back' : 'Create your account',
                      style: AppType.title(t),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _isLogin
                          ? 'Sign in to pick up where you left off.'
                          : 'Start logging every set in under a minute.',
                      style: AppType.secondary(t),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // E-post fält
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_isLoading,
                style: AppType.body(t),
                cursorColor: t.primary,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    size: 19,
                    color: t.textSecondary,
                  ),
                ),
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Please enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Lösenord fält
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_isLoading,
                style: AppType.body(t),
                cursorColor: t.primary,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                    color: t.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _togglePasswordVisibility,
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 19,
                      color: t.textSecondary,
                    ),
                  ),
                ),
                onFieldSubmitted: (_) {
                  if (!_isLoading) _submitAuthForm();
                },
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters long.';
                  }
                  return null;
                },
              ),

              // Only sign-up needs the rule spelled out up front.
              if (!_isLogin) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: t.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Use at least 6 characters. You cannot change your '
                        'email later.',
                        style: AppType.caption(t),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Submit-knapp
              AppButton(
                label: _isLogin ? 'Sign in' : 'Create account',
                onPressed: _isLoading ? null : _submitAuthForm,
                loading: _isLoading,
                expand: true,
                size: AppButtonSize.large,
                icon: _isLogin
                    ? Icons.login_rounded
                    : Icons.person_add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch(AppColors t) {
    return SwapTransitionBox(
      value: _isLogin,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _isLogin
                  ? "Don't have an account?"
                  : 'Already have an account?',
              style: AppType.secondary(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton.ghost(
            label: _isLogin ? 'Register' : 'Login',
            onPressed: _isLoading ? null : _toggleMode,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }
}

/// The logo mark, the app name and the one-line promise above the form.
class _Wordmark extends ConsumerWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: t.primaryGradientDiagonal,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: t.shadowPrimaryGlow,
          ),
          child: Icon(Icons.bolt_rounded, size: 32, color: t.onPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Repicore',
          textAlign: TextAlign.center,
          style: AppType.display(t).copyWith(fontSize: 38),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Every set counted. Every lift trending up.',
          textAlign: TextAlign.center,
          style: AppType.secondary(t),
        ),
      ],
    );
  }
}
