import 'package:flutter/material.dart';
import 'package:thyscan/core/theme/constants/app_typography.dart';

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text('splash screen')));
  }
}
