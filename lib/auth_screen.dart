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
  /// Snack duration for messages people need to actually read.
  static const Duration _longMessage = Duration(seconds: 4);

  // Enkel state för att växla mellan Login och Register
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isSendingReset = false;
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

  /// Tangentbordets autokorrigering lägger gärna till ett mellanslag sist.
  String get _email => _emailController.text.trim();

  static bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    return at > 0 && at < value.length - 1 && !value.contains(' ');
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

  Future<void> _submitAuthForm() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);

    final password = _passwordController.text;

    try {
      final user =
          _isLogin
              ? await _authService.signInWithEmailAndPassword(_email, password)
              : await _authService.registerWithEmailAndPassword(
                _email,
                password,
              );

      // Lyckas det navigerar AuthGate automatiskt vidare till appen.
      if (user == null && mounted) {
        AppSnack.show(
          context,
          ref,
          AuthService.messageFor('unknown'),
          isError: true,
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        AppSnack.show(
          context,
          ref,
          e.message,
          isError: true,
          duration: _longMessage,
        );
      }
    } catch (e) {
      debugPrint('Auth failed: $e');
      if (mounted) {
        AppSnack.show(
          context,
          ref,
          AuthService.messageFor('unknown'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email;
    if (!_looksLikeEmail(email)) {
      AppSnack.show(
        context,
        ref,
        'Enter your email above first.',
        isError: true,
      );
      _emailFocus.requestFocus();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSendingReset = true);

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        // Firebase säger inte om kontot finns, så det gör inte vi heller.
        AppSnack.show(
          context,
          ref,
          'If $email has an account, a reset link is on its way.',
          icon: Icons.mark_email_read_rounded,
          duration: _longMessage,
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        AppSnack.show(
          context,
          ref,
          e.message,
          isError: true,
          duration: _longMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
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
    final busy = _isLoading || _isSendingReset;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        // Lets password managers fill the pair, and offer to save it.
        child: AutofillGroup(
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    style: AppType.title(t),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // E-post fält
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  enabled: !busy,
                  style: AppType.body(t),
                  cursorColor: t.primary,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      size: 19,
                      color: t.textSecondary,
                    ),
                  ),
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator:
                      (value) =>
                          _looksLikeEmail((value ?? '').trim())
                              ? null
                              : 'Enter a valid email address.',
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
                  autofillHints: [
                    _isLogin
                        ? AutofillHints.password
                        : AutofillHints.newPassword,
                  ],
                  enabled: !busy,
                  style: AppType.body(t),
                  cursorColor: t.primary,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    // Only sign-up needs the rule spelled out up front.
                    helperText: _isLogin ? null : 'At least 6 characters',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      size: 19,
                      color: t.textSecondary,
                    ),
                    suffixIcon: AppIconButton(
                      icon:
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                      tooltip:
                          _obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: _togglePasswordVisibility,
                      filled: false,
                      size: 36,
                      iconSize: 19,
                      color: t.textSecondary,
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (!busy) _submitAuthForm();
                  },
                  validator:
                      (value) =>
                          (value == null || value.length < 6)
                              ? 'Password must be at least 6 characters.'
                              : null,
                ),

                if (_isLogin)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    // A Row, not an Align: given a bounded width the button
                    // stretches to fill it and its label ends up centred.
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton.ghost(
                          label: 'Forgot password?',
                          size: AppButtonSize.small,
                          loading: _isSendingReset,
                          onPressed: busy ? null : _resetPassword,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: AppSpacing.xl),

                const SizedBox(height: AppSpacing.md),

                // Submit-knapp
                AppButton(
                  label: _isLogin ? 'Sign in' : 'Create account',
                  onPressed: busy ? null : _submitAuthForm,
                  loading: _isLoading,
                  expand: true,
                  size: AppButtonSize.large,
                ),
              ],
            ),
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
              _isLogin ? 'New here?' : 'Already have an account?',
              style: AppType.secondary(t),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton.ghost(
            label: _isLogin ? 'Create account' : 'Sign in',
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
        // The mark on a plain raised tile, the accent only in the glyph — the
        // Sign in button below is the one gradient on the screen.
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.outline),
            boxShadow: t.shadowMedium,
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: t.primaryGradientDiagonal.createShader,
            child: const Icon(Icons.bolt_rounded, size: 34),
          ),
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
