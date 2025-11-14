import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.goNamed('onboarding');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final size = MediaQuery.of(context).size;
    final double baseWidth = 375;
    final double scale = size.width / baseWidth;

    final double logoSize = 100 * scale;
    final double titleFontSize = 36 * scale;
    final double taglineFontSize = 16 * scale;
    final double spacing = 18 * scale;

    return Scaffold(
      // backgroundColor: colorScheme.background, //
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo with Glow
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.6),
                          blurRadius: 30 * scale,
                          spreadRadius: 8 * scale,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '[≡]',
                        style: TextStyle(
                          fontSize: 44 * scale,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing),

                // Fade-in Text
                Opacity(
                  opacity: _opacityAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        'ThyScan',
                        style: GoogleFonts.inter(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary, // White
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: spacing * 0.5),
                      // Text(
                      //   'Scan. Save. Simplify.',
                      //   style: GoogleFonts.inter(
                      //     fontSize: taglineFontSize,
                      //     color: colorScheme.onPrimary,
                      //     letterSpacing: 0.5,
                      //     height: 1.4,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
