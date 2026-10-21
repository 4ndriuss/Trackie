import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:country_code_picker/country_code_picker.dart';

import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_dialog.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  DateTime? _selectedBirthDate;
  String _selectedCountryCode = '+62';
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime initialDate = DateTime.now().subtract(const Duration(days: 18 * 365));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark ? ColorScheme.dark(primary: AppTheme.primary, onPrimary: Colors.white, surface: Theme.of(context).cardColor) : ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _handleSignup() async {
    setState(() => _submitted = true);
    if (_formKey.currentState!.validate()) {
      if (_selectedBirthDate == null) {
        await showErrorDialog(
          context,
          title: 'Validation Error',
          message: 'Please select your birth date.',
          buttonText: 'OK',
        );
        return;
      }
      
      setState(() => _isLoading = true);
      
      final authProvider = context.read<AuthProvider>();
      final fullPhoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';
      
      final success = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: fullPhoneNumber,
        birthDate: _selectedBirthDate,
      );
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      if (success) {
        await showSuccessDialog(
          context,
          title: 'Registration Successful',
          message: 'Your account has been created. Please log in to continue.',
          buttonText: 'Go to Login',
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Go back to login screen
          },
        );
      } else {
        await showErrorDialog(
          context,
          title: 'Registration Failed',
          message: authProvider.error ?? 'Something went wrong.',
          buttonText: 'Try Again',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Sign up',
                        style: GoogleFonts.urbanist(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an account to continue!',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        label: 'Full Name',
                        hint: 'e.g. John Doe',
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Full Name cannot be empty';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Email',
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Email cannot be empty';
                          if (!value.contains('@')) return 'Invalid email format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Birth of date field
                      Text(
                        'BIRTH OF DATE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectBirthDate(context),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedBirthDate == null
                                    ? 'dd/mm/yyyy'
                                    : DateFormat('dd/MM/yyyy').format(_selectedBirthDate!),
                                style: GoogleFonts.urbanist(
                                  color: _selectedBirthDate == null ? const Color(0xFF9CA3AF) : theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFF9CA3AF), size: 20),
                            ],
                          ),
                        ),
                      ),
                      if (_submitted && _selectedBirthDate == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 16),
                          child: Text(
                            'Birth date is required',
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Phone Number field
                      Text(
                        'PHONE NUMBER',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CountryCodePicker(
                              onChanged: (countryCode) {
                                _selectedCountryCode = countryCode.dialCode ?? '+62';
                              },
                              initialSelection: 'ID',
                              favorite: const ['+62', 'ID'],
                              showCountryOnly: false,
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                              flagWidth: 24,
                              padding: EdgeInsets.zero,
                              textStyle: GoogleFonts.urbanist(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: theme.dividerColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.urbanist(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '(454) 726-0592',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Phone number is required';
                                  if (value.trim().length < 8 || value.trim().length > 15) {
                                    return 'Invalid phone number length';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Set Password',
                        hint: '••••••••',
                        isPassword: true,
                        controller: _passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password cannot be empty';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        text: 'Register',
                        onPressed: _handleSignup,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: GoogleFonts.urbanist(color: const Color(0xFF6B7280)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Login',
                      style: GoogleFonts.urbanist(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
