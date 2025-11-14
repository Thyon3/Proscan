part of 'router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => Splash())],
);
