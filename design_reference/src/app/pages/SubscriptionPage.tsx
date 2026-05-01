import { useState } from 'react';
import { useNavigate } from 'react-router';
import { CreditCard, Check } from 'lucide-react';
import { AppHeader } from '../components/AppHeader';
import { Card } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { toast } from 'sonner';

export default function SubscriptionPage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);

  const handleSubscribe = async () => {
    setLoading(true);

    // Simulate Stripe checkout redirect
    setTimeout(() => {
      toast.success('Redirecionando para checkout do Stripe...');
      // In production, this would call a Cloud Function to create a Stripe checkout session
      // and redirect to the Stripe payment page
      setLoading(false);
    }, 1500);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-50 to-pink-50">
      <AppHeader title="Assinatura" subtitle="Continue usando o app" showBack />

      <div className="max-w-2xl mx-auto p-4 py-8">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold mb-2">Continuar usando o app</h1>
          <p className="text-gray-600">
            Escolha o plano ideal para o seu negócio
          </p>
        </div>

        <Card className="p-6 mb-6">
          <div className="flex items-start gap-4 mb-6">
            <div className="w-12 h-12 bg-purple-600 rounded-full flex items-center justify-center flex-shrink-0">
              <CreditCard className="w-6 h-6 text-white" />
            </div>
            <div className="flex-1">
              <h2 className="text-2xl font-bold mb-1">Assinatura mensal</h2>
              <p className="text-gray-600">Acesso completo a todas as funcionalidades</p>
            </div>
          </div>

          <div className="bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-lg p-6 mb-6">
            <div className="text-center">
              <div className="text-4xl font-bold mb-2">R$ 49,90</div>
              <div className="text-purple-100">por mês</div>
            </div>
          </div>

          <div className="space-y-3 mb-6">
            <div className="flex items-start gap-3">
              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <span className="text-sm">Agendamentos ilimitados</span>
            </div>
            <div className="flex items-start gap-3">
              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <span className="text-sm">Gestão completa de clientes</span>
            </div>
            <div className="flex items-start gap-3">
              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <span className="text-sm">Sistema de fidelidade</span>
            </div>
            <div className="flex items-start gap-3">
              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <span className="text-sm">Controle de estoque</span>
            </div>
            <div className="flex items-start gap-3">
              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <span className="text-sm">Relatórios e DRE</span>
            </div>
            <div className="flex items-start gap-3">
              <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <span className="text-sm">Suporte prioritário</span>
            </div>
          </div>

          <Button
            size="lg"
            className="w-full"
            onClick={handleSubscribe}
            disabled={loading}
          >
            {loading ? 'Processando...' : 'Assinar agora'}
          </Button>
        </Card>

        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-sm text-blue-800">
          <p className="font-medium mb-1">Pagamento seguro</p>
          <p className="text-blue-700">
            O pagamento é processado de forma segura pelo Stripe. Cobrança automática no cartão todo mês. 
            Cancele quando quiser.
          </p>
        </div>
      </div>
    </div>
  );
}
