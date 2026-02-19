import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';


import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmpassword = TextEditingController();
  final mobile = TextEditingController();
  final pin = TextEditingController();
  final confirmPin = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool hidePassword  = true;
  bool hideConfirmPassword  = true;
  bool hidePin  = true;
  bool hideConfirmPin  = true;
  String _userType = 'normal'; // Default to normal user

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    password.dispose();
    confirmpassword.dispose();
    mobile.dispose();
    pin.dispose();
    confirmPin.dispose();
    address.dispose();
    city.dispose();
    super.dispose();
  }



  Future<void> registerUser() async {
    if (!formKey.currentState!.validate()) return;

    // Validate password match
    if (password.text != confirmpassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate PIN match
    if (pin.text != confirmPin.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate PIN is 4 digits
    if (pin.text.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN must be 4 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await context.read<AuthService>().registerWithEmailAndPassword(
        firstName: firstName.text.trim(),
        lastName: lastName.text.trim(),
        email: email.text.trim(),
        password: password.text.trim(),
        mobileNo: mobile.text.trim(),
        pin: pin.text.trim(),
        address: address.text.trim(),
        city: city.text.trim(),
        userType: _userType,
      );

      // Auto logout after registration
      await FirebaseAuth.instance.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           content: Text(
            'Registration successful. Wait for admin approval email.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );

    } on FirebaseAuthException catch (e) {

    } catch (e) {

    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Information
                _buildSectionHeader('Personal Information'),
                const SizedBox(height: 12),

                // First Name & Last Name Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: firstName,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter first name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: lastName,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter last name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: email,
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
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Mobile No Field
                TextFormField(
                  controller: mobile,
                  decoration: InputDecoration(
                    labelText: 'Mobile No',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter mobile number';
                    }
                    if (value.length < 10) {
                      return 'Please enter valid mobile number';
                    }
                    return null;
                  },
                ),

                // Security Section
                _buildSectionHeader('Security'),
                const SizedBox(height: 12),

                // Password Field
                TextFormField(
                  controller: password,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword  = !hidePassword ;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: hidePassword ,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: confirmpassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hideConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hideConfirmPassword  = !hideConfirmPassword ;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: hideConfirmPassword ,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != password.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // PIN Field
                TextFormField(
                  controller: pin,
                  decoration: InputDecoration(
                    labelText: '4-digit PIN',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePin  ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePin  = !hidePin ;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: hidePin ,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter 4-digit PIN';
                    }
                    if (value.length != 4 || !RegExp(r'^\d{4}$').hasMatch(value)) {
                      return 'PIN must be 4 digits';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm PIN Field
                TextFormField(
                  controller: confirmPin,
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hideConfirmPin
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          hideConfirmPin  = !hideConfirmPin ;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: hideConfirmPin ,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm PIN';
                    }
                    if (value != pin.text) {
                      return 'PINs do not match';
                    }
                    return null;
                  },
                ),

                // Address Section
                _buildSectionHeader('Address'),
                const SizedBox(height: 12),

                // Address Field
                TextFormField(
                  controller: address,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    prefixIcon: const Icon(Icons.home_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // City Field
                TextFormField(
                  controller: city,
                  decoration: InputDecoration(
                    labelText: 'City',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter city';
                    }
                    return null;
                  },
                ),

                // User Type Section
                _buildSectionHeader('User Type'),
                const SizedBox(height: 12),

                // User Type Radio Buttons
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: const Text('Normal User'),
                        value: 'normal',
                        groupValue: _userType,
                        onChanged: (value) {
                          setState(() {
                            _userType = value.toString();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text('Admin'),
                        value: 'admin',
                        groupValue: _userType,
                        onChanged: (value) {
                          setState(() {
                            _userType = value.toString();
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Terms Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: true,
                      onChanged: (value) {},
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: 'I agree to the ',
                          style: GoogleFonts.inter(color: Colors.grey),
                          children: [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: GoogleFonts.inter(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.inter(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      'Register',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Login',
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryColor,
      ),
    );
  }
}