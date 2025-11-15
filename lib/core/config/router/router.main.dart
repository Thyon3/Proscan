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
    GoRoute(
      path: '/forgotpassword',
      name: 'forgotpassword',
      builder: (context, state) {
        return ForgotPasswordScreen();
      },
    ),
    GoRoute(
      path: '/verifyotp',
      name: 'verifyotp',
      builder: (context, state) {
        // TODO   pass the email
        final email = 'asnakemengesha79@gmail.com';
        return VerifyOtpScreen(email: email);
      },
    ),
    GoRoute(
      path: '/resetpassword',
      name: 'resetpassword',
      builder: (context, state) {
        // TODO   pass the email
        final email = 'asnakemengesha79@gmail.com';
        return CreateNewPasswordScreen();
      },
    ),
  ],
);
