import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscurePass = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/appmainscreen');
    }
  }

  // Theme-aware polished fill and border (same approach as Forgot screen)
  Color _inputFillColor(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;
    // Light: subtle brand tint; Dark: soft white overlay on surface
    return isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.06), cs.surface)
        : Color.alphaBlend(cs.primary.withOpacity(0.04), cs.surface);
  }

  Color _inputBorderColor(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;
    return isDark
        ? Colors.white.withOpacity(0.12)
        : cs.outline.withOpacity(0.25);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive padding and max width
            final double horizontalPad = (constraints.maxWidth * 0.075).clamp(
              16.0,
              28.0,
            );

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  24,
                  horizontalPad,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      Text(
                        'Sign in to your account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: scheme.onBackground,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email
                            _buildFloatingField(
                              context: context,
                              label: 'Email Address',
                              hint: 'yourname@example.com',
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              icon: Iconsax.sms,
                              keyboardType: TextInputType.emailAddress,
                              scheme: scheme,
                              fillColor: _inputFillColor(context),
                              borderColor: _inputBorderColor(context),
                              onSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_passFocus),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return 'Email is required';
                                final rx = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!rx.hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password
                            _buildFloatingField(
                              context: context,
                              label: 'Password',
                              hint: 'Enter your password',
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              icon: Iconsax.lock,
                              obscureText: _obscurePass,
                              scheme: scheme,
                              fillColor: _inputFillColor(context),
                              borderColor: _inputBorderColor(context),
                              onSubmitted: (_) => _login(),
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Iconsax.eye_slash
                                      : Iconsax.eye,
                                  size: 20,
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                                onPressed: () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Remember Me & Forgot
                            _buildRememberForgot(scheme),
                            const SizedBox(height: 28),

                            // Login Button
                            _buildLoginButton(scheme),
                            const SizedBox(height: 28),

                            // Divider
                            _buildDivider(scheme),
                            const SizedBox(height: 24),

                            // Social Login
                            _buildSocialLogin(scheme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Sign Up
                      _buildSignUpSection(scheme),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required ColorScheme scheme,
    required Color fillColor,
    required Color borderColor,
    required BuildContext context,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: obscureText
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: scheme.onBackground,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
          color: scheme.onBackground.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(
          color: scheme.onBackground.withOpacity(0.42),
        ),
        prefixIcon: Icon(icon, size: 20, color: scheme.primary),
        suffixIcon: suffix,
        filled: true,
        fillColor: fillColor, // refined fill to match Forgot screen
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildRememberForgot(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remember Me
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _rememberMe ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: _rememberMe
                        ? scheme.primary
                        : scheme.onSurface.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: _rememberMe
                    ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                'Remember me',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: scheme.onBackground.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Forgot Password
        GestureDetector(
          onTap: () => context.push('/forgotpassword'),
          child: Text(
            'Forgot password?',
            style: GoogleFonts.inter(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Text(
                'Sign In',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: scheme.outline.withOpacity(0.2), thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or continue with',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onBackground.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: scheme.outline.withOpacity(0.2), thickness: 1),
        ),
      ],
    );
  }

  Widget _buildSocialLogin(ColorScheme scheme) {
    final bg = _inputFillColor(context);
    final border = _inputBorderColor(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          icon: Icons.g_mobiledata,
          onTap: () {},
          scheme: scheme,
          bg: bg,
          borderColor: border,
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          icon: Icons.apple,
          onTap: () {},
          scheme: scheme,
          bg: bg,
          borderColor: border,
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          icon: Icons.facebook,
          onTap: () {},
          scheme: scheme,
          bg: bg,
          borderColor: border,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme scheme,
    required Color bg,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Icon(
          icon,
          color: scheme.onBackground.withOpacity(0.7),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSignUpSection(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: scheme.onBackground.withOpacity(0.7),
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/signup'),
          child: Text(
            'Create account',
            style: GoogleFonts.inter(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
