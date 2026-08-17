import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).signUpWithEmailAndPassword(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      SnackbarHelper.showSuccess(context, 'Account created successfully!');
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.error != null && mounted) {
        SnackbarHelper.showError(context, state.error!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: size.height * 0.05),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join Trip Expense Manager today',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(
                        Icons.person_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your phone number',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Minimum 8 characters',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hint: 'Re-enter your password',
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icon(
                        Icons.lock_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onSubmitted: (_) => _handleSignup(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Create Account',
                isLoading: authState.isLoading,
                onPressed: _handleSignup,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushReplacement('/login'),
                    child: const Text('Login'),
                  ),
                ],
              ),
              SizedBox(height: size.height * 0.03),
            ],
          ),
        ),
      ),
    );
  }
}
