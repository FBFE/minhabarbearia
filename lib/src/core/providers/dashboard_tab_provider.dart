import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aba ativa do dashboard do dono (0=Início … 5=Relatórios), para "Ver agenda" no Início.
final dashboardTabIndexProvider = StateProvider<int>((ref) => 0);
