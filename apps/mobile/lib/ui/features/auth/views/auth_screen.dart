import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/services/app_preferences_repository.dart';
import '../../../core/design_system.dart';
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
  int _heroIndex = 0;
  bool _loadedHeroIndex = false;

  static const _heroAssets = [
    'assets/images/hero_food.webp',
    'assets/images/hero_food.webp',
    'assets/images/hero_food.webp',
    'assets/images/hero_food.webp',
    'assets/images/hero_food.webp',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedHeroIndex) return;
    _loadedHeroIndex = true;
    context
        .read<AppPreferencesRepository>()
        .nextAuthHeroIndex(count: _heroAssets.length)
        .then((index) {
      if (!mounted) return;
      setState(() => _heroIndex = index);
    });
  }

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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: FreshColors.screen,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 24 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthTopBar(),
                  const SizedBox(height: FreshSpacing.xxl),
                  const _HeroHeadline(),
                  const SizedBox(height: FreshSpacing.xl),
                  _FoodHero(assetPath: _heroAssets[_heroIndex]),
                  const SizedBox(height: FreshSpacing.lg),
                  FreshCard(
                    padding: const EdgeInsets.all(18),
                    radius: FreshRadii.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_registerMode) ...[
                          TextField(
                            key: const ValueKey('display_name_field'),
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: FreshSpacing.md),
                        ],
                        TextField(
                          key: const ValueKey('email_field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: FreshSpacing.md),
                        TextField(
                          key: const ValueKey('password_field'),
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: FreshSpacing.lg),
                        FilledButton.icon(
                          key: const ValueKey('auth_submit_button'),
                          onPressed: viewModel.isLoading ? null : _submit,
                          icon: viewModel.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.keyboard_double_arrow_right_rounded),
                          label: Text(
                              _registerMode ? 'Create account' : 'Get Started'),
                        ),
                        TextButton(
                          key: const ValueKey('auth_toggle_mode_button'),
                          onPressed: () =>
                              setState(() => _registerMode = !_registerMode),
                          child: Text(
                            _registerMode
                                ? 'Use existing account'
                                : 'Create an account',
                          ),
                        ),
                        if (viewModel.error != null) ...[
                          const SizedBox(height: FreshSpacing.sm),
                          FreshStatusBanner(
                            icon: Icons.error_outline_rounded,
                            title: 'Sign in failed',
                            message: viewModel.error!,
                            color: FreshColors.coral,
                          ),
                        ],
                      ],
                    ),
                  ),
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
      return viewModel.register(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
      );
    }
    return viewModel.login(_emailController.text, _passwordController.text);
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: FreshColors.limeWash,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_fire_department_rounded,
            color: FreshColors.limeDeep,
            size: 22,
          ),
        ),
        const SizedBox(width: FreshSpacing.sm),
        Text(
          'Better Calories',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 46,
          fontWeight: FontWeight.w700,
          height: 1.25,
        );
    return RichText(
      text: TextSpan(
        style: style,
        children: const [
          TextSpan(text: 'Track your\ncalories better.'),
        ],
      ),
    );
  }
}

class _FoodHero extends StatelessWidget {
  const _FoodHero({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FreshRadii.xl),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: Image.asset(
                  assetPath,
                  key: ValueKey(assetPath),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(90),
              child: Image.asset(
                'assets/images/leaf_accent.webp',
                width: 120,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Positioned(
            left: 26,
            top: 84,
            child: _CalorieBubble(label: '504 Kcal'),
          ),
          const Positioned(
            left: 146,
            top: 18,
            child: _CalorieBubble(label: '132 Kcal', rotate: 0.14),
          ),
          const Positioned(
            right: 18,
            top: 120,
            child: _CalorieBubble(label: '320 Kcal'),
          ),
        ],
      ),
    );
  }
}

class _CalorieBubble extends StatelessWidget {
  const _CalorieBubble({required this.label, this.rotate = -0.08});

  final String label;
  final double rotate;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: FreshColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: FreshColors.ruleSoft),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10080907),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
