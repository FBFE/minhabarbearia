import { useParams, Link } from 'react-router';
import { Gift, QrCode, AlertCircle } from 'lucide-react';
import { AppHeader } from '../../components/AppHeader';
import { BottomNav } from '../../components/BottomNav';
import { Card } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { getBusinessBySlug, getClientData } from '../../lib/auth';

export default function ClientLoyaltyPage() {
  const { slug } = useParams();
  const business = getBusinessBySlug(slug || '');
  const client = getClientData();

  const totalStamps = 10;
  const currentStamps = client?.stamps || 0;
  const isEligibleForReward = currentStamps >= totalStamps;

  if (!business) {
    return <div>Estabelecimento não encontrado</div>;
  }

  if (!client) {
    return (
      <div className="min-h-screen bg-gray-50">
        <AppHeader title={business.name} subtitle="Programa de fidelidade" />
        <div className="flex flex-col items-center justify-center p-8 min-h-[calc(100vh-3.5rem)]">
          <AlertCircle className="w-16 h-16 text-purple-500 mb-4" />
          <h2 className="text-xl font-semibold mb-2">Verifique seu cadastro</h2>
          <p className="text-gray-600 mb-6 text-center">
            Faça login para ver seu cartão fidelidade
          </p>
          <Link to={`/b/${slug}`}>
            <Button>Ir para página inicial</Button>
          </Link>
        </div>
        <BottomNav type="client" slug={slug} />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <AppHeader
        title={business.name}
        subtitle={isEligibleForReward ? 'Você ganhou!' : 'Complete e ganhe'}
      />

      <div className="max-w-2xl mx-auto p-4 space-y-6">
        <Card className="p-6">
          <div className="text-center mb-6">
            <div className="inline-flex items-center justify-center w-16 h-16 bg-purple-100 rounded-full mb-3">
              <Gift className="w-8 h-8 text-purple-600" />
            </div>
            <h2 className="text-2xl font-bold mb-2">Cartão Fidelidade</h2>
            <p className="text-gray-600">
              {isEligibleForReward
                ? 'Parabéns! Você completou o cartão!'
                : `Complete ${totalStamps} selos e ganhe um corte grátis`}
            </p>
          </div>

          <div className="grid grid-cols-5 gap-3 mb-6">
            {Array.from({ length: totalStamps }).map((_, index) => (
              <div
                key={index}
                className={`aspect-square rounded-full flex items-center justify-center text-sm font-semibold transition-all ${
                  index < currentStamps
                    ? 'bg-purple-600 text-white shadow-lg scale-105'
                    : 'bg-gray-200 text-gray-400'
                }`}
              >
                {index < currentStamps ? '✓' : index + 1}
              </div>
            ))}
          </div>

          <div className="text-center mb-6">
            <div className="text-4xl font-bold text-purple-600 mb-1">
              {currentStamps} / {totalStamps}
            </div>
            <div className="text-gray-600">
              {isEligibleForReward
                ? 'Selos completos!'
                : `Faltam ${totalStamps - currentStamps} ${
                    totalStamps - currentStamps === 1 ? 'selo' : 'selos'
                  }`}
            </div>
          </div>

          {isEligibleForReward && (
            <div className="bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg p-6 mb-4">
              <div className="text-center mb-4">
                <h3 className="font-semibold mb-2">Seu cupom de desconto</h3>
                <p className="text-sm text-gray-600 mb-4">Mostre este QR Code no atendimento</p>
              </div>
              <div className="w-48 h-48 bg-white mx-auto rounded-lg flex items-center justify-center border-2 border-purple-200">
                <QrCode className="w-32 h-32 text-purple-600" />
              </div>
              <div className="text-center mt-4">
                <p className="text-sm font-mono text-gray-600">CUPOM-{client.id.slice(0, 8).toUpperCase()}</p>
              </div>
            </div>
          )}

          <Link to={`/b/${slug}`}>
            <Button className="w-full">Agendar horário</Button>
          </Link>
        </Card>

        <Card className="p-4 bg-blue-50 border-blue-200">
          <div className="flex gap-3">
            <Gift className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
            <div className="text-sm text-blue-900">
              <p className="font-medium mb-1">Como funciona?</p>
              <p>
                A cada atendimento, você ganha um selo. Complete {totalStamps} selos e ganhe um
                corte grátis!
              </p>
            </div>
          </div>
        </Card>
      </div>

      <BottomNav type="client" slug={slug} />
    </div>
  );
}
