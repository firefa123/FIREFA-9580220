import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';


class FirefaLogo extends StatelessWidget {
  const FirefaLogo({
    super.key,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          "FIREFA",
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          "Restaurant Operating System",
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
          ),
        ),

      ],
    );
  }
}