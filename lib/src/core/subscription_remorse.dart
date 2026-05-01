import 'models/barber_shop.dart';

/// Política de **Corte por arrependimento** (CDC e regras de produto neste app).
///
/// **Trial pelo cadastro (7 dias)**  
/// Ao criar o negócio no app, há um período de trial gratuito (padrão 7 dias) antes de
/// assinar o Stripe. Isso não é cobrança: é apenas para experimentar funcionalidades
/// sem pagar pelo plano pago — é independente da janela de reembolso abaixo.
///
/// **Após você pagar a assinatura (Stripe)**  
/// 1. **Primeiros 7 dias corridos** desde o momento em que aquela cobrança foi paga:
///    aparece «Solicitar reembolso». Se confirmares, o estorno é feito na Stripe e o
///    acesso **Pro corta logo** (bloqueado).
/// 2. **Do 8º dia até o fim do ciclo pago (~30 dias, segundo o Stripe)**:
///    o mesmo botão não aparece; em troca podes **Cancelar renovação** — continuas com
///    acesso **Pro até a data de fim do período** já pago, mas **não** há cobrança no
///    ciclo seguinte (não há estorno pelo app).
/// 3. **Trava de reincidência**: se este negócio **já tiver utilizado um reembolso**
///    automático pela assinatura antes, mesmo que voltes a assinar outra vez, não voltamos
///    a oferecer reembolso automático pela app — só cancelamento da renovação.
extension SubscriptionRemorsePolicy on BarberShop {
  static const Duration remorseRefundWindow = Duration(days: 7);

  /// Início dos 7 dias de arrependimento com base na última cobrança paga conhecida.
  DateTime? get remorseRefundPeriodEnd => subscriptionLastInvoicePaidAt?.add(remorseRefundWindow);

  bool get _hasPaidClock => subscriptionLastInvoicePaidAt != null;

  bool get isWithinPaidRemorseWindow {
    if (!_hasPaidClock) return false;
    final end = remorseRefundPeriodEnd!;
    return DateTime.now().isBefore(end);
  }

  /// Reembolso automático já foi usado para este negócio (persiste mesmo após nova assinatura).
  bool get isBlockedFromAutomaticRefund => subscriptionRefundEverUsed;

  /// Pode aparecer botão «Solicitar reembolso»: cobrança paga há menos de 7 dias e sem trava por reincidência.
  bool mayShowAutomaticRefundButton({
    required bool hasProAccess,
  }) {
    if (stripeSubscriptionId == null) return false;
    if (!hasProAccess) return false;
    if (subscriptionStatus == 'refunded') return false;
    if (subscriptionStatus == 'past_due') return false;
    if (subscriptionStatus != 'active') return false;
    if (isBlockedFromAutomaticRefund) return false;
    if (!_hasPaidClock) {
      return true;
    }
    return isWithinPaidRemorseWindow;
  }

  /// Pode aparecer botão principal «Cancelar renovação» até ao fim do período atual.
  bool mayCancelRenewalInsteadOfRefund({
    required bool hasProAccess,
  }) {
    if (stripeSubscriptionId == null) return false;
    if (!hasProAccess) return false;
    if (subscriptionStatus == 'refunded') return false;
    if (cancelAtPeriodEnd) return false;
    final s = subscriptionStatus;
    return s == 'active' || s == 'past_due';
  }

  bool get explainsWhyRefundHiddenOnlyCancel {
    if (stripeSubscriptionId == null || subscriptionRefundEverUsed) return false;
    if (subscriptionStatus != 'active') return false;
    return _hasPaidClock && !isWithinPaidRemorseWindow;
  }
}
