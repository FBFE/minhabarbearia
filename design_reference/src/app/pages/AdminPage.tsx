import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { RefreshCw, Store, AlertCircle } from 'lucide-react';
import { AppHeader } from '../components/AppHeader';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { getCurrentUser, isAdmin } from '../lib/auth';

interface BusinessListing {
  id: string;
  name: string;
  slug: string;
  createdAt: string;
  trialEndDate: string;
  subscriptionStatus: 'trial' | 'active' | 'expired';
}

export default function AdminPage() {
  const navigate = useNavigate();
  const [businesses, setBusinesses] = useState<BusinessListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [hasAccess, setHasAccess] = useState(false);

  useEffect(() => {
    const user = getCurrentUser();
    if (!user) {
      navigate('/login');
      return;
    }

    const userIsAdmin = isAdmin(user.uid);
    setHasAccess(userIsAdmin);

    if (userIsAdmin) {
      loadBusinesses();
    } else {
      setLoading(false);
    }
  }, [navigate]);

  const loadBusinesses = () => {
    setLoading(true);
    // Mock data
    setTimeout(() => {
      setBusinesses([
        {
          id: 'biz-1',
          name: 'Barbearia Moderna',
          slug: 'moderna',
          createdAt: '2026-02-14',
          trialEndDate: '2026-04-14',
          subscriptionStatus: 'trial',
        },
        {
          id: 'biz-2',
          name: 'Salão Elegance',
          slug: 'elegance',
          createdAt: '2026-01-10',
          trialEndDate: '2026-03-10',
          subscriptionStatus: 'active',
        },
        {
          id: 'biz-3',
          name: 'Barbearia Classic',
          slug: 'classic',
          createdAt: '2025-12-01',
          trialEndDate: '2026-02-01',
          subscriptionStatus: 'expired',
        },
      ]);
      setLoading(false);
    }, 500);
  };

  if (!hasAccess && !loading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <AppHeader title="Acesso Negado" showBack />
        <div className="flex flex-col items-center justify-center p-8 min-h-[calc(100vh-3.5rem)]">
          <AlertCircle className="w-16 h-16 text-red-500 mb-4" />
          <h2 className="text-xl font-semibold mb-2">Você não tem acesso ao painel admin</h2>
          <p className="text-gray-600 mb-6 text-center">
            Este painel é restrito a administradores do sistema.
          </p>
          <Button onClick={() => navigate('/dashboard')}>
            Voltar ao dashboard
          </Button>
        </div>
      </div>
    );
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'trial':
        return <Badge variant="secondary">Trial</Badge>;
      case 'active':
        return <Badge className="bg-green-500">Ativo</Badge>;
      case 'expired':
        return <Badge variant="destructive">Expirado</Badge>;
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 pb-6">
      <AppHeader
        title="Painel do App"
        subtitle="Gerenciamento de negócios"
        showBack
        actions={{
          showLogout: true,
          onLogout: () => navigate('/login'),
        }}
        backgroundColor="bg-gray-900"
        textColor="text-white"
      />

      <div className="max-w-4xl mx-auto p-4 space-y-4">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-semibold">Negócios cadastrados</h2>
          <Button
            variant="outline"
            size="sm"
            onClick={loadBusinesses}
            disabled={loading}
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
        </div>

        <div className="space-y-3">
          {businesses.map((business) => (
            <Card key={business.id} className="p-4">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center flex-shrink-0">
                  <Store className="w-6 h-6 text-purple-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2 mb-2">
                    <div className="min-w-0 flex-1">
                      <h3 className="font-semibold truncate">{business.name}</h3>
                      <p className="text-sm text-gray-600">/{business.slug}</p>
                    </div>
                    {getStatusBadge(business.subscriptionStatus)}
                  </div>
                  <div className="grid grid-cols-2 gap-2 text-sm text-gray-600">
                    <div>
                      <span className="font-medium">Cadastro:</span> {business.createdAt}
                    </div>
                    <div>
                      <span className="font-medium">Fim trial:</span> {business.trialEndDate}
                    </div>
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
