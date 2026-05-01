import { Link } from 'react-router';
import { Share2, Calendar, AlertCircle } from 'lucide-react';
import { Card } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';

interface DashboardHomeProps {
  user: any;
  business: any;
}

export function DashboardHome({ user, business }: DashboardHomeProps) {
  const getDaysRemaining = (endDate: string) => {
    const end = new Date(endDate);
    const now = new Date();
    const diff = Math.ceil((end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    return diff;
  };

  const daysRemaining = business?.trialEndDate ? getDaysRemaining(business.trialEndDate) : 0;
  const isTrialExpiringSoon = daysRemaining > 0 && daysRemaining <= 7;
  const isTrialExpired = daysRemaining <= 0;

  const shareLink = business ? `${window.location.origin}/b/${business.slug}` : '';

  return (
    <div className="space-y-4">
      <Card className="p-6">
        <h2 className="text-2xl font-bold mb-2">Bem-vindo ao Dashboard</h2>
        <p className="text-gray-600">{user?.email}</p>
      </Card>

      {business && (isTrialExpiringSoon || isTrialExpired) && (
        <Card className={`p-4 border-2 ${isTrialExpired ? 'border-red-500 bg-red-50' : 'border-yellow-500 bg-yellow-50'}`}>
          <div className="flex items-start gap-3">
            <AlertCircle className={`w-6 h-6 flex-shrink-0 ${isTrialExpired ? 'text-red-600' : 'text-yellow-600'}`} />
            <div className="flex-1">
              <h3 className="font-semibold mb-1">
                {isTrialExpired ? 'Período de teste expirado' : 'Período de teste terminando'}
              </h3>
              <p className="text-sm mb-3">
                {isTrialExpired
                  ? 'Seu período de teste expirou. Assine agora para continuar usando o app.'
                  : `Restam apenas ${daysRemaining} ${daysRemaining === 1 ? 'dia' : 'dias'} do seu período de teste.`}
              </p>
              <Link to="/dashboard/assinar">
                <Button size="sm" variant={isTrialExpired ? 'destructive' : 'default'}>
                  Assinar agora
                </Button>
              </Link>
            </div>
          </div>
        </Card>
      )}

      {business ? (
        <Card className="p-6 space-y-4">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1">
              <h3 className="text-xl font-semibold mb-1">{business.name}</h3>
              <p className="text-gray-600 mb-2">/{business.slug}</p>
              <Badge variant={business.subscriptionStatus === 'active' ? 'default' : 'secondary'}>
                {business.subscriptionStatus === 'trial' ? 'Período de teste' : 'Ativo'}
              </Badge>
            </div>
          </div>

          <div className="p-3 bg-gray-50 rounded-lg">
            <p className="text-sm text-gray-600 mb-2">Link para compartilhar:</p>
            <div className="flex gap-2">
              <input
                type="text"
                value={shareLink}
                readOnly
                className="flex-1 px-3 py-2 text-sm bg-white border rounded-md"
              />
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  navigator.clipboard.writeText(shareLink);
                }}
              >
                <Share2 className="w-4 h-4" />
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 pt-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">24</div>
              <div className="text-sm text-gray-600">Agendamentos hoje</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">156</div>
              <div className="text-sm text-gray-600">Clientes ativos</div>
            </div>
          </div>
        </Card>
      ) : (
        <Card className="p-6">
          <h3 className="text-lg font-semibold mb-2">Vincular ou criar negócio</h3>
          <p className="text-gray-600 mb-4">
            Você ainda não tem um negócio vinculado. Configure seu estabelecimento para começar.
          </p>
          <Link to="/dashboard/settings">
            <Button>Configurar negócio</Button>
          </Link>
        </Card>
      )}

      <div className="grid sm:grid-cols-2 gap-4">
        <Card className="p-6">
          <Calendar className="w-8 h-8 text-purple-600 mb-3" />
          <h3 className="font-semibold mb-2">Próximos agendamentos</h3>
          <p className="text-sm text-gray-600 mb-4">Veja e gerencie sua agenda</p>
          <a href="#agenda">
            <Button variant="outline" size="sm">Ver agenda</Button>
          </a>
        </Card>

        <Card className="p-6">
          <Share2 className="w-8 h-8 text-purple-600 mb-3" />
          <h3 className="font-semibold mb-2">Compartilhe seu link</h3>
          <p className="text-sm text-gray-600 mb-4">Divulgue para seus clientes</p>
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              if (shareLink) {
                navigator.clipboard.writeText(shareLink);
                alert('Link copiado!');
              }
            }}
          >
            Copiar link
          </Button>
        </Card>
      </div>
    </div>
  );
}
