import 'models/barber_shop.dart';

/// Aviso de trial: quantos dias antes do fim mostrar o banner laranja (trial de 7 dias).
const int kSubscriptionTrialWarningDays = 2;

/// Se o dono tem acesso às funcionalidades pro do dashboard.
///
/// - **Reembolso** (`refunded`) → acesso imediato revogado.
/// - **Trial** → válido até [BarberShop.trialEndsAt].
/// - **Ativo** → válido; se [BarberShop.cancelAtPeriodEnd], até o fim do período pago
///   ([BarberShop.subscriptionCurrentPeriodEnd]).
/// - **Cancelado** → ainda pode usar até o fim do período pago, se a data for futura
///   (ex.: cancelou mas não reembolsou).
/// - **Atraso** (`past_due`) → mantém acesso (retentativas de pagamento; pode ajustar depois).
bool barberShopHasProAccess(BarberShop shop) {
  final now = DateTime.now();
  if (shop.subscriptionStatus == 'refunded') return false;

  if (shop.subscriptionStatus == 'past_due') {
    return true;
  }

  if (shop.subscriptionStatus == 'trial') {
    if (shop.trialEndsAt == null) return true;
    return shop.trialEndsAt!.isAfter(now);
  }

  if (shop.subscriptionStatus == 'active') {
    if (shop.cancelAtPeriodEnd && shop.subscriptionCurrentPeriodEnd != null) {
      return shop.subscriptionCurrentPeriodEnd!.isAfter(now);
    }
    return true;
  }

  if (shop.subscriptionStatus == 'canceled') {
    if (shop.subscriptionCurrentPeriodEnd != null) {
      return shop.subscriptionCurrentPeriodEnd!.isAfter(now);
    }
    return false;
  }

  if (shop.subscriptionStatus == 'none') {
    return false;
  }

  return false;
}
