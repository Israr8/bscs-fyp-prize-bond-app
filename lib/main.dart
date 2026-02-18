import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Screens
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/admin_panel_screen.dart';
import 'package:app/screens/auth/pin_authentication_screen.dart';
import 'package:app/screens/auth/register_screen.dart'; // Add this
// Services
import 'package:app/services/auth_service.dart';
import 'package:app/services/notification_service.dart';
// Theme
import 'package:app/utils/theme.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Pakbond - Prize Bond Checker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AuthWrapper(),
        // routes for better navigation
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/admin': (context) => const AdminPanelScreen(),
          '/pin-auth': (context) => const PinAuthenticationScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle connection errors
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Authentication Error',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Retry or go to login
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        //  Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Checking authentication...'),
                ],
              ),
            ),
          );
        }

        //  No user logged in - Show Login Screen
        if (!snapshot.hasData || snapshot.data == null) {
          // Small delay to ensure smooth transition
          Future.microtask(() {
            if (authService.currentUser != null) {
               authService.signOut();
            }
          });
          return const LoginScreen();
        }

        // User logged in but data not loaded yet - show loading
        if (authService.currentUser == null) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading user data...'),
                ],
              ),
            ),
          );
        }

        final currentUser = authService.currentUser!;

        //  Admin user - Go to Admin Panel
        if (currentUser.userType == 'admin') {
          return const AdminPanelScreen();
        }

        //  Normal user - Check approval status
        if (!currentUser.isApproved || currentUser.status != 'approved') {
          return _buildPendingApprovalScreen(context, authService);
        }

        // Approved normal user - PIN Authentication
        return const PinAuthenticationScreen();
      },
    );
  }

  Widget _buildPendingApprovalScreen(BuildContext context, AuthService auth) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //  ICON SECTION - THIS WAS MISSING
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 80,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 30),


              const Text(
                'Account Pending Approval',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Your account is under review by the administrator. '
                      'You will receive an email notification once your account is approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // BUTTON SECTION - THIS PART IS CORRECT
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    // Show a snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logging out...'),
                        duration: Duration(seconds: 1),
                      ),
                    );

                    // Small delay to show snackbar
                    await Future.delayed(const Duration(milliseconds: 500));

                    // Perform logout
                    await auth.signOut();

                    // AuthWrapper will handle navigation automatically
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'LOGOUT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}