import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController(text: 'demo@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _nameController = TextEditingController(text: 'Test User');
  bool _registerMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Cal Tracker', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  if (_registerMode) TextField(key: const ValueKey('display_name_field'), controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
                  if (_registerMode) const SizedBox(height: 12),
                  TextField(key: const ValueKey('email_field'), controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('password_field'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('auth_submit_button'),
                    onPressed: viewModel.isLoading ? null : _submit,
                    child: Text(_registerMode ? 'Create account' : 'Log in'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _registerMode = !_registerMode),
                    child: Text(_registerMode ? 'Use existing account' : 'Create an account'),
                  ),
                  if (viewModel.error != null) Text(viewModel.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() {
    final viewModel = context.read<AuthViewModel>();
    if (_registerMode) {
      return viewModel.register(_emailController.text, _passwordController.text, _nameController.text);
    }
    return viewModel.login(_emailController.text, _passwordController.text);
  }
}
