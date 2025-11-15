import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/theme/constants/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (_formKey.currentState!.validate()) {
      // TODO: Send reset code
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('6-digit code sent to ${_emailCtrl.text}'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // Title
                Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: scheme.onBackground,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Enter your email address and we\'ll send you a 6-digit code to reset your password.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: scheme.onBackground.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Email Field
                _buildField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  scheme: scheme,
                  isDark: isDark,
                  validator: (v) {
                    if (v!.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Send Code Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                    child: Text(
                      'Send Code',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: scheme.onBackground.withOpacity(0.3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: GoogleFonts.inter(
                          color: scheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: scheme.onBackground.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Apple Button
                _socialButton(
                  label: 'Continue with Apple',
                  icon: Icons.apple,
                  onTap: () {},
                  scheme: scheme,
                  isDark: isDark,
                  isApple: true,
                ),
                SizedBox(height: 15),
                _socialButton(
                  label: 'Continue with Google',
                  icon: Icons.g_mobiledata,
                  onTap: () {},
                  scheme: scheme,
                  isDark: isDark,
                  isApple: true,
                ),
                const SizedBox(height: 32),

                // Login Link
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.inter(
                          color: scheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/login'),
                        child: Text(
                          'Log In',
                          style: GoogleFonts.inter(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // REUSABLE FIELD
  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required ColorScheme scheme,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: !isDark
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(color: scheme.onBackground, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: scheme.onBackground.withOpacity(0.5),
              ),
              prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
              filled: true,
              fillColor: isDark ? scheme.surface : Color(0xFFF8FFF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  // SOCIAL BUTTON
  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme scheme,
    required bool isDark,
    bool isApple = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? scheme.surface : const Color(0xFFF8FFF9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.onBackground.withOpacity(0.2)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            if (isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isApple && !isDark ? Colors.black : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
