import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../presentation/providers/authentication_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: CustomTextField(
            controller: emailController,
            label: 'Email',
            hint: 'Enter your email address',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final success = await ref
                  .read(authProvider.notifier)
                  .resetPassword(emailController.text.trim());

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                if (success) {
                  SnackbarHelper.showSuccess(
                    context,
                    'Password reset email sent. Check your inbox.',
                  );
                } else {
                  final error = ref.read(authProvider).error;
                  SnackbarHelper.showError(
                    context,
                    error ?? 'Failed to send reset email.',
                  );
                }
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
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
              SizedBox(height: size.height * 0.08),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 40,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue managing your trips',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
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
                      validator: Validators.validatePassword,
                      onSubmitted: (_) => _handleLogin(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Login',
                isLoading: authState.isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushReplacement('/signup'),
                    child: const Text('Create Account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
