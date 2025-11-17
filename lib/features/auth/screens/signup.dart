import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please agree to the Terms & Conditions'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/home');
    }
  }

  // Theme-aware polished fill & border (matches Login/Forgot)
  Color _inputFillColor(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isDark = t.brightness == Brightness.dark;
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
            // Responsive horizontal padding + max width, keyboard-safe bottom inset
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
                        'Create your account',
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
                            // Name
                            _buildFloatingField(
                              context: context,
                              label: 'Name',
                              hint: 'Enter your full name',
                              controller: _nameCtrl,
                              focusNode: _nameFocus,
                              icon: Iconsax.user,
                              scheme: scheme,
                              fillColor: _inputFillColor(context),
                              borderColor: _inputBorderColor(context),
                              onSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_emailFocus),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return 'Name is required';
                                if (value.length < 2) {
                                  return 'Please enter a valid name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Email
                            _buildFloatingField(
                              label: 'Email',
                              context: context,
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
                              hint: 'Create a strong password',
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              icon: Iconsax.lock,
                              obscureText: _obscurePass,
                              scheme: scheme,
                              fillColor: _inputFillColor(context),
                              borderColor: _inputBorderColor(context),
                              onSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_confirmFocus),
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
                                if (v.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(
                                  r'^(?=.*[a-zA-Z])(?=.*\d)',
                                ).hasMatch(v)) {
                                  return 'Must contain letters and numbers';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Confirm Password
                            _buildFloatingField(
                              context: context,
                              label: 'Confirm Password',
                              hint: 'Confirm your password',
                              controller: _confirmCtrl,
                              focusNode: _confirmFocus,
                              icon: Iconsax.lock_1,
                              obscureText: _obscureConfirm,
                              scheme: scheme,
                              fillColor: _inputFillColor(context),
                              borderColor: _inputBorderColor(context),
                              onSubmitted: (_) => _signup(),
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Iconsax.eye_slash
                                      : Iconsax.eye,
                                  size: 20,
                                  color: scheme.onSurface.withOpacity(0.5),
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Terms Agreement
                            _buildTermsAgreement(scheme),
                            const SizedBox(height: 28),

                            // Sign Up Button
                            _buildSignupButton(scheme),
                            const SizedBox(height: 28),

                            // Divider
                            _buildDivider(scheme),
                            const SizedBox(height: 24),

                            // Social Sign Up
                            _buildSocialLogin(scheme),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Login Link
                      _buildLoginSection(scheme),
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
        fillColor: fillColor,
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

  Widget _buildTermsAgreement(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreeToTerms
                    ? scheme.primary
                    : scheme.onBackground.withOpacity(0.3),
                width: 2,
              ),
              color: _agreeToTerms ? scheme.primary : Colors.transparent,
            ),
            child: _agreeToTerms
                ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 14,
                color: scheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => context.push('/terms'),
                    child: Text(
                      'Terms & Conditions',
                      style: GoogleFonts.inter(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => context.push('/privacy'),
                    child: Text(
                      'Privacy Policy',
                      style: GoogleFonts.inter(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton(ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signup,
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
                'Create Account',
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
            'Or sign up with',
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

  Widget _buildLoginSection(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: scheme.onBackground.withOpacity(0.7),
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/login'),
          child: Text(
            'Log In',
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
