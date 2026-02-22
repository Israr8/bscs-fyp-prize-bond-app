import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Screens
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/screens/auth/admin_panel_screen.dart';
import 'package:app/screens/auth/pin_authentication_screen.dart';
import 'package:app/screens/auth/register_screen.dart';
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
    print('Firebase init ok');
  } catch (e) {
    print('Firebase init error: $e');
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
        // routes for better navigation
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AuthWrapper(),
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

        // Handle connection errors
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
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
                      // Retry or go to login
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        //  Loading state
          );
        }

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
        //  No user logged in - Show Login Screen
          );
        }
          // Small delay to ensure smooth transition

        if (!snapshot.hasData || snapshot.data == null) {
          Future.microtask(() {
            if (authService.currentUser != null) {
               authService.signOut();
            }
          });
        // User logged in but data not loaded yet - show loading
          return const LoginScreen();
        }

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
        //  Admin user - Go to Admin Panel

        final currentUser = authService.currentUser!;

        if (currentUser.userType == 'admin') {
        //  Normal user - Check approval status
          return const AdminPanelScreen();
        }

        if (!currentUser.isApproved || currentUser.status != 'approved') {
        // Approved normal user - PIN Authentication
          return _buildPendingApprovalScreen(context, authService);
        }

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
              //  ICON SECTION - THIS WAS MISSING
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              // BUTTON SECTION - THIS PART IS CORRECT
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                    // Show a snackbar
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logging out...'),
                        duration: Duration(seconds: 1),
                    // Small delay to show snackbar
                      ),
                    );


                    // AuthWrapper will handle navigation automatically
                    // Perform logout

                    await Future.delayed(const Duration(milliseconds: 500));
                    await auth.signOut();
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