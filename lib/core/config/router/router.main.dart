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
      path: '/guesmodeprofilescreen',
      name: 'guesmodeprofilescreen',
      builder: (context, state) {
        return (ProfileGuestScreen());
      },
    ),
    GoRoute(
      path: '/premiumuserprofilescreen',
      name: 'premiumuserprofilescreen',
      builder: (context, state) {
        return (ProUserProfileScreen());
      },
    ),
    GoRoute(
      path: '/freeuserprofilescreen',
      name: 'freeuserprofilescreen',
      builder: (context, state) {
        return (FreeUserProfileScreen());
      },
    ),
    GoRoute(
      path: '/editprofilescreen',
      name: 'editprofilescreen',
      builder: (context, state) {
        return (EditProfileScreen());
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
      path: '/recentscansselection',
      name: 'recentscansselection',
      builder: (context, state) {
        return RecentScansSection();
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
      path: '/homescreen',
      name: 'homescreen',
      builder: (context, state) {
        return HomeScreen();
      },
    ),
    GoRoute(
      path: '/helpandsupport',
      name: 'helpandsupport',
      builder: (context, state) {
        return HelpSupportScreen();
      },
    ),
    GoRoute(
      path: '/appmainscreen',
      name: 'appmainscreen',
      builder: (context, state) {
        return AppMainScreen();
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
