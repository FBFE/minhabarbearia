import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aba ativa do dashboard do dono (0=Início … 5=Relatórios), para "Ver agenda" no Início.
final dashboardTabIndexProvider = StateProvider<int>((ref) => 0);

/// Utilizador (ex.: admin) pediu fluxo «cadastrar meu negócio» ([DashboardPage] mostra onboarding em vez de /admin).
final ownerOnboardingRequestProvider = StateProvider<bool>((ref) => false);
