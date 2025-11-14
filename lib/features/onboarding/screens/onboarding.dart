import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _glowController;
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _pulseAnimation;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Scan Your Documents',
      description:
          'AI captures, cleans, and enhances every page with precision.',
      icon: Icons.document_scanner,
    ),
    OnboardingItem(
      title: 'Unlock Your Text',
      description:
          'Extract, edit, search, and copy text from any scan instantly.',
      icon: Icons.text_fields,
    ),
    OnboardingItem(
      title: 'Never Lose a Scan',
      description: 'Secure cloud sync — access your files anywhere, anytime.',
      icon: Icons.cloud_done,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );

    _pageController.addListener(() {
      setState(() => _currentPage = _pageController.page?.round() ?? 0);
      if (_pageController.page?.remainder(1) == 0) {
        _pulseController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onGetStarted() => context.go('/signup');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final scale = size.width / 375;

    return Scaffold(
      body: Stack(
        children: [
          // ULTRA PREMIUM BACKGROUND
          _PremiumBackground(glow: _glowAnimation, scheme: scheme),

          // PAGE CONTENT WITH 3D TILT
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final progress =
                  (_pageController.hasClients && _pageController.page != null)
                  ? (_pageController.page! - index).abs().clamp(0.0, 1.0)
                  : 1.0;
              final tilt = progress * 15;

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((index - _currentPage) * 0.1)
                  ..rotateX(tilt * pi / 180),
                alignment: Alignment.center,
                child: _buildPremiumCard(_items[index], scale, scheme),
              );
            },
          ),

          // BOTTOM CONTROLS
          Positioned(
            bottom: 70,
            left: 32,
            right: 32,
            child: Column(
              children: [
                _buildPremiumDots(scale, scheme),
                const SizedBox(height: 32),
                _buildPremiumButton(scale, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PREMIUM CARD
  Widget _buildPremiumCard(
    OnboardingItem item,
    double scale,
    ColorScheme scheme,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // GLASSMORPHIC ICON CARD
          ClipRRect(
            borderRadius: BorderRadius.circular(32 * scale),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.all(36 * scale),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32 * scale),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 88 * scale, color: Colors.white),
              ),
            ),
          ),

          SizedBox(height: 56 * scale),

          // TITLE
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: scheme.primary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          SizedBox(height: 20 * scale),

          // DESCRIPTION
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Colors.white70,
              height: 1.6,
              fontSize: 15 * scale,
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  // ANIMATED DOTS WITH PULSE
  Widget _buildPremiumDots(double scale, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_items.length, (i) {
        final isActive = _currentPage == i;
        return GestureDetector(
          onTap: () => _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final pulse = isActive ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: pulse,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8 * scale),
                  height: 12 * scale,
                  width: isActive ? 36 * scale : 12 * scale,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            colors: [
                              scheme.primary,
                              scheme.primary.withOpacity(0.7),
                            ],
                          )
                        : null,
                    color: isActive ? null : Colors.white38,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: scheme.primary.withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // PREMIUM BUTTON
  Widget _buildPremiumButton(double scale, ColorScheme scheme) {
    final isLast = _currentPage == _items.length - 1;
    return GestureDetector(
      onTap: isLast
          ? _onGetStarted
          : () => _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 64 * scale,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primary.withBlue(150)],
          ),
          borderRadius: BorderRadius.circular(32 * scale),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Text(
            isLast ? 'Get Started' : 'Continue',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// BACKGROUND WITH PARTICLES
class _PremiumBackground extends StatelessWidget {
  final Animation<double> glow;
  final ColorScheme scheme;

  const _PremiumBackground({required this.glow, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0E0A), Color(0xFF12181B), Color(0xFF0A0E0A)],
            ),
          ),
          child: Stack(
            children: [
              // Animated glow orbs
              _GlowOrb(
                left: -120,
                top: -80,
                size: 380,
                opacity: glow.value * 0.4,
              ),
              _GlowOrb(
                right: -100,
                bottom: -120,
                size: 420,
                opacity: glow.value * 0.3,
              ),
              _GlowOrb(
                left: 50,
                top: 200,
                size: 300,
                opacity: glow.value * 0.2,
              ),

              // Subtle particles
              ...List.generate(6, (i) => _Particle(i: i, glow: glow.value)),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double? left, right, top, bottom;
  final double size;
  final double opacity;

  const _GlowOrb({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(opacity),
        ),
      ),
    );
  }
}

class _Particle extends StatelessWidget {
  final int i;
  final double glow;

  const _Particle({required this.i, required this.glow});

  @override
  Widget build(BuildContext context) {
    final random = Random(i);
    final left = random.nextDouble() * 400 - 50;
    final top = random.nextDouble() * 800;
    final size = random.nextDouble() * 4 + 2;

    return Positioned(
      left: left,
      top: top,
      child: AnimatedOpacity(
        opacity: glow,
        duration: const Duration(seconds: 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}
