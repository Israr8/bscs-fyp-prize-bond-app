import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:app/screens/auth/register_screen.dart';
import 'package:app/screens/guest_home_screen.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/screens/auth/pin_authentication_screen.dart';
import 'package:app/screens/auth/admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
// Stateful is leye use kiya kuon k loading aur password visibility handle karni hai updation honi hha na

}

class _LoginScreenState extends State<LoginScreen> {
  final _userEmail = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; //Login button pe spinner dikhane k leye
  bool _obscurePassword = true; // Password initially hide karne k leye

  @override
  void dispose() {
    // Controllers free karne k leye dispose
    _userEmail.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // login_screen.dart me _login function update karein
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return; // Form valid hai ya nahi check kar rahe

    setState(() => _isLoading = true); // Spinner

    try {
      // Firebase se login karna
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _userEmail.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = userCredential.user!.uid;

      // Firestore se user ki  details le lo
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut(); // Agar user doc ni mila to logout
        throw Exception('User data not found');
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final userType = data['userType'] ?? 'normal';
      final isApproved = data['isApproved'] ?? false;
      final status = data['status'] ?? 'pending';

      // Update last login
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // user Type or approval check kar k navigate karo
      if (userType == 'admin') {
        // Admin ---->    Navigate to Admin Panel
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
              (route) => false,
        );
      } else if (!isApproved || status != 'approved') {
        // Normal user not approved ---->>  Show pending screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => _buildPendingApprovalScreen(),
          ),
              (route) => false,
        );
      } else {
        // Approved normal user - Go to PIN screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PinAuthenticationScreen()),
              (route) => false,
        );
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Try again later.';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  // Pending approval screen dikhaane k widget
  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              'Account Pending Approval',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Your account is under review ---->>> You will receive an email once approved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _loginAsGuest() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const GuestHomeScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo/Title
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.money,
                    size: 50,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Pakbond',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Prize Bond Checking App',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                // Email Field
                TextFormField(
                  controller: _userEmail,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Forgot password
                    },
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      'Login',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey[300]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey[300]),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Social Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      Icons.facebook,
                      'Facebook',
                      Colors.blue,
                      onPressed: () {
                        // Facebook login
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildSocialButton(
                      Icons.g_mobiledata,
                      'Google',
                      Colors.red,
                      onPressed: () {
                        // Google login
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildGuestButton(), // Updated Guest Button
                  ],
                ),

                const SizedBox(height: 32),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Register',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, Color color, {VoidCallback? onPressed}) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 30),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildGuestButton() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.grey, size: 30),
            onPressed: _loginAsGuest,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Guest',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}