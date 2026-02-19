import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/pin_authentication_screen.dart';
import 'package:app/screens/auth/admin_panel_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final authService = context.read<AuthService>();

    // Listen to auth state changes
    authService.userStream.listen((User? user) async {
      if (user != null) {
        // User is logged in
        final isAdmin = await authService.isAdmin();

        if (isAdmin) {
          // Navigate to Admin Panel
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
          );
        } else {
          // Navigate to PIN Authentication for normal users
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PinAuthenticationScreen()),
          );
        }
      } else {
        // User is not logged in
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }, onError: (error) {
      // Handle auth errors
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.money,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pakbond',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Prize Bond Checking App',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}