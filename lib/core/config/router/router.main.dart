part of 'router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => SplashScreen()),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) {
        return OnboardingScreen();
      },
    ),
    GoRoute(
      path: '/signup',
      name: 'singup',
      builder: (context, state) {
        return SignupScreen();
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        return LoginScreen();
      },
    ),
  ],
);
