// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/theme_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  void _checkInitialRoute() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final slug = _getSlugFromUrl();
    if (slug != null && slug.isNotEmpty) {
      ref.read(currentSlugProvider.notifier).state = slug;
      context.go('/b/$slug');
      return;
    }

    final authState = ref.read(authStateChangesProvider);
    authState.when(
      data: (user) {
        if (!mounted) return;
        if (user != null) {
          context.go('/dashboard');
        } else {
          context.go('/login');
        }
      },
      loading: () {
        if (!mounted) return;
        context.go('/login');
      },
      error: (_, __) {
        if (!mounted) return;
        context.go('/login');
      },
    );
  }

  String? _getSlugFromUrl() {
    final uri = Uri.parse(html.window.location.href);
    return uri.queryParameters['slug'];
  }

  @override
  Widget build(BuildContext context) {
    // Design reference: gradient purple-600 via pink-500 to purple-700
    const purple600 = Color(0xFF9333EA);
    const pink500 = Color(0xFFEC4899);
    const purple700 = Color(0xFF7C3AED);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [purple600, pink500, purple700],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.content_cut_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Meu Negócio',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
