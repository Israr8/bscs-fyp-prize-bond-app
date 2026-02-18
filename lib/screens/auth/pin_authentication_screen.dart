import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/auth/login_screen.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class PinAuthenticationScreen extends StatefulWidget {
  const PinAuthenticationScreen({super.key});

  @override
  State<PinAuthenticationScreen> createState() => _PinAuthenticationScreenState();
}

class _PinAuthenticationScreenState extends State<PinAuthenticationScreen> {
  final List<String> _enteredPin = [];
  bool _isLoading = false;
  bool _showError = false;

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin.add(number);
        _showError = false;
      });
    }

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
        _showError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pin = _enteredPin.join('');
      final authService = context.read<AuthService>();

      debugPrint('🔐 Verifying PIN: $pin');
      final isValid = await authService.verifyPin(pin);

      if (isValid) {
        debugPrint('✅ PIN verified successfully');

        // Navigate to home screen
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
          );
        }
      } else {
        debugPrint('❌ Invalid PIN');
        if (mounted) {
          setState(() {
            _showError = true;
            _enteredPin.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ PIN verification error: $e');
      if (mounted) {
        setState(() {
          _showError = true;
          _enteredPin.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('If you have forgotten your PIN, you need to:'),
            const SizedBox(height: 10),
            const Text('1. Logout from your account'),
            const Text('2. Contact admin to reset your PIN'),
            const Text('3. Admin will reset your PIN to default (0000)'),
            const SizedBox(height: 15),
            Text(
              'Default PIN after reset: 0000',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logoutAndGoToLogin();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutAndGoToLogin() async {
    final authService = context.read<AuthService>();
    try {
      setState(() {
        _isLoading = true;
      });

      await authService.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Logout failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPinIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _enteredPin.length
                ? AppColors.primaryColor
                : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Widget _buildNumberButton(String number) {
    return SizedBox(
      width: 80,
      height: 80,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _onNumberPressed(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryColor,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: Colors.black26,
        ),
        child: Text(
          number,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
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

                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'Enter PIN',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Enter your 4-digit PIN to continue',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // PIN Indicators
                  _buildPinIndicator(),

                  if (_showError) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Invalid PIN. Please try again.',
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],

                  const SizedBox(height: 60),

                  // Numeric Keypad
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNumberButton('1'),
                          _buildNumberButton('2'),
                          _buildNumberButton('3'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNumberButton('4'),
                          _buildNumberButton('5'),
                          _buildNumberButton('6'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNumberButton('7'),
                          _buildNumberButton('8'),
                          _buildNumberButton('9'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 80),
                          _buildNumberButton('0'),
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: IconButton(
                              onPressed: _isLoading ? null : _onBackspacePressed,
                              icon: const Icon(Icons.backspace_outlined, size: 30),
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Forgot PIN Button
                  TextButton(
                    onPressed: _showForgotPinDialog,
                    child: Text(
                      'Forgot PIN?',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Back to Login Button
                  TextButton(
                    onPressed: _logoutAndGoToLogin,
                    child: Text(
                      'Back to Login',
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_isLoading)
                    const CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}