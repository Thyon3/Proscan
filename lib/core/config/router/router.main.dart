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
      path: '/camerascreen',
      name: 'camerascreen',
      builder: (context, state) {
        final extra = state.extra;
        CameraScreenConfig? config;
        if (extra is CameraScreenConfig) {
          config = extra;
        } else if (extra is ScanMode) {
          config = CameraScreenConfig(initialMode: extra);
        }

        return SmartCameraScreen(
          initialMode: config?.initialMode ?? ScanMode.document,
          restrictToInitialMode: config?.restrictToInitialMode ?? false,
          returnCapturePath: config?.returnCapturePath ?? false,
        );
      },
    ),
    GoRoute(
      path: '/editscanscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is EditScanArgs) {
          return EditScanScreen(
            imagePath: extra.imagePath,
            initialMode: extra.initialMode,
            documentId: extra.documentId,
            imagePaths: extra.imagePaths,
          );
        } else if (extra is String && extra.isNotEmpty) {
          // Backwards compatibility: allow passing just the image path.
          return EditScanScreen(
            imagePath: extra,
            initialMode: ScanMode.document,
          );
        }
        throw ArgumentError('EditScanScreen requires image path.');
      },
    ),
    GoRoute(
      path: '/savepdfscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          return SavePdfScreen(
            imagePaths: extra['imagePaths'] as List<String>,
            pdfFileName: extra['pdfFileName'] as String,
            documentId: extra['documentId'] as String?, // Optional for existing documents
          );
        }
        throw ArgumentError(
          'SavePdfScreen requires imagePaths and pdfFileName.',
        );
      },
    ),
    GoRoute(
      path: '/texteditorscreen',
      builder: (_, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          final imagePath = extra['imagePath'] as String?;
          final extractedText = extra['extractedText'] as String?;

          if (extractedText != null) {
            return TextEditorScreen(
              extractedText: extractedText,
              imagePath: imagePath,
            );
          } else if (imagePath != null) {
            // If only imagePath is provided, we'll process OCR in the screen
            return TextEditorScreen(extractedText: '', imagePath: imagePath);
          }
        }
        throw ArgumentError(
          'TextEditorScreen requires imagePath or extractedText.',
        );
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
    GoRoute(
      path: '/toolscreen',
      name: 'toolscreen',
      builder: (context, state) => ToolsScreen(),
    ),
    GoRoute(
      path: '/translationeditorscreen',
      name: 'translationeditorscreen',
      builder: (context, state) {
        return TranslationEditorScreen();
      },
    ),
  ],
);
