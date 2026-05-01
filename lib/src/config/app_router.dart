import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_listener.dart';
import '../core/providers/auth_providers.dart';
import '../features/admin/presentation/admin_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/dashboard/presentation/dashboard_assinar_page.dart';
import '../features/dashboard/presentation/dashboard_billing_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/public_booking/presentation/client_agenda_page.dart';
import '../features/public_booking/presentation/client_fidelidade_page.dart';
import '../features/public_booking/presentation/client_complete_profile_page.dart';
import '../features/public_booking/presentation/client_login_page.dart';
import '../features/public_booking/presentation/client_perfil_page.dart';
import '../features/public_booking/presentation/client_register_page.dart';
import '../features/public_booking/presentation/public_booking_page.dart';
import '../features/public_booking/presentation/public_shell_page.dart';
import '../features/public_booking/presentation/staff_access_page.dart';
import '../features/public_booking/presentation/staff_agenda_page.dart';
import '../features/public_booking/presentation/staff_shell_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final authRefreshNotifierProvider =
    Provider<AuthRefreshNotifier>((ref) => AuthRefreshNotifier());

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRefresh = ref.watch(authRefreshNotifierProvider);
  ref.onDispose(() => authRefresh.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context);
      final authAsync = container.read(authStateChangesProvider);
      final user = authAsync.valueOrNull;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;
      final isLogin = location == '/login';
      final isRegister = location == '/register';
      final isDashboard = location == '/dashboard' || location.startsWith('/dashboard/');
      final isPublicBooking = location.startsWith('/b/');

      if (isPublicBooking) {
        // /b/{slug} — link curto: abre a página inicial do negócio (agendamento); ?ref= preservado
        final pathSegments = state.uri.pathSegments;
        if (pathSegments.length == 2) {
          final slug = pathSegments[1];
          final q = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/b/$slug/agendar$q';
        }
        return null;
      }

      if (isLoggedIn && (isLogin || isRegister)) {
        return '/dashboard';
      }

      if (isLoggedIn && location == '/') {
        return '/dashboard';
      }

      if (!isLoggedIn && (isDashboard || location == '/admin')) {
        return '/login';
      }

      if (!isLoggedIn && location == '/') {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
        routes: [
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => const DashboardSettingsPage(),
          ),
          GoRoute(
            path: 'assinatura',
            name: 'assinatura',
            builder: (context, state) => const DashboardBillingPage(),
          ),
          GoRoute(
            path: 'assinar',
            name: 'assinar',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return DashboardAssinarPage(
                checkoutSessionId: q['session_id'],
                checkoutSuccess: q['success'] == '1',
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/b/:slug',
        name: 'publicBooking',
        // redirect global envia /b/:slug → /b/:slug/agendar
        redirect: (context, state) => null,
        routes: [
          GoRoute(
            path: 'agendar',
            name: 'publicAgendar',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              final refParam = state.uri.queryParameters['ref'];
              return PublicShellPage(
                slug: slug,
                child: PublicBookingPage(slug: slug, refParam: refParam),
              );
            },
          ),
          GoRoute(
            path: 'agenda',
            name: 'clientAgenda',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              return PublicShellPage(
                slug: slug,
                child: ClientAgendaPage(slug: slug),
              );
            },
          ),
          GoRoute(
            path: 'fidelidade',
            name: 'clientFidelidade',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              return PublicShellPage(
                slug: slug,
                child: ClientFidelidadePage(slug: slug),
              );
            },
          ),
          GoRoute(
            path: 'perfil',
            name: 'clientPerfil',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              return PublicShellPage(
                slug: slug,
                child: ClientPerfilPage(slug: slug),
              );
            },
          ),
          GoRoute(
            path: 'cadastro',
            name: 'clientRegister',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              final refParam = state.uri.queryParameters['ref'];
              return PublicShellPage(
                slug: slug,
                child: ClientRegisterPage(slug: slug, refParam: refParam),
              );
            },
          ),
          GoRoute(
            path: 'login',
            name: 'clientLogin',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              return PublicShellPage(
                slug: slug,
                child: ClientLoginPage(slug: slug),
              );
            },
          ),
          GoRoute(
            path: 'funcionario',
            name: 'staffAccess',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              return StaffShellPage(slug: slug, child: StaffAccessPage(slug: slug));
            },
            routes: [
              GoRoute(
                path: 'agenda',
                name: 'staffAgenda',
                builder: (context, state) {
                  final slug = state.pathParameters['slug']!;
                  return StaffShellPage(
                    slug: slug,
                    title: 'Minha agenda',
                    child: StaffAgendaPage(slug: slug),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'complete-profile',
            name: 'clientCompleteProfile',
            builder: (context, state) {
              final slug = state.pathParameters['slug']!;
              final extra = state.extra as Map<String, dynamic>?;
              final name = extra?['name'] as String? ?? '';
              final email = extra?['email'] as String? ?? '';
              final uid = extra?['uid'] as String? ?? '';
              final photoUrl = extra?['photoUrl'] as String?;
              final authMethod = extra?['authMethod'] as String? ?? 'google';
              return PublicShellPage(
                slug: slug,
                child: ClientCompleteProfilePage(
                  slug: slug,
                  googleName: name,
                  googleEmail: email,
                  googleUid: uid,
                  googlePhotoUrl: photoUrl,
                  authMethod: authMethod,
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
});
