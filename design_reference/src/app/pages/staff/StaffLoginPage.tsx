import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { UserCheck, AlertCircle } from 'lucide-react';
import { AppHeader } from '../../components/AppHeader';
import { Card } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { getBusinessBySlug, setStaffStatus } from '../../lib/auth';
import { toast } from 'sonner';

export default function StaffLoginPage() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const business = getBusinessBySlug(slug || '');
  const [loading, setLoading] = useState(false);

  const handleGoogleLogin = async () => {
    setLoading(true);

    try {
      // Simulate Google login
      await new Promise((resolve) => setTimeout(resolve, 1000));

      // Mock: Check if email is in staff list
      const isStaff = Math.random() > 0.3; // 70% chance of being staff

      if (isStaff) {
        setStaffStatus(true);
        toast.success('Login realizado com sucesso!');
        navigate(`/b/${slug}/funcionario/agenda`);
      } else {
        // Show dialog asking if they want to go to client booking
        const goToClient = window.confirm(
          'Você não está cadastrado como funcionário. Deseja ir para a página de agendamento como cliente?'
        );
        if (goToClient) {
          navigate(`/b/${slug}`);
        }
      }
    } catch (error) {
      toast.error('Erro ao fazer login');
    } finally {
      setLoading(false);
    }
  };

  if (!business) {
    return <div>Estabelecimento não encontrado</div>;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <AppHeader title={business.name} subtitle="Acesso para funcionários" />

      <div className="max-w-md mx-auto p-4 py-12">
        <Card className="p-8 text-center">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-purple-100 rounded-full mb-6">
            <UserCheck className="w-10 h-10 text-purple-600" />
          </div>

          <h2 className="text-2xl font-bold mb-2">Acesso para Funcionários</h2>
          <p className="text-gray-600 mb-8">
            Entre com sua conta Google cadastrada no sistema
          </p>

          <Button
            size="lg"
            className="w-full"
            onClick={handleGoogleLogin}
            disabled={loading}
          >
            <svg className="w-5 h-5 mr-2" viewBox="0 0 24 24">
              <path
                fill="currentColor"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="currentColor"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="currentColor"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
              />
              <path
                fill="currentColor"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
              />
            </svg>
            {loading ? 'Entrando...' : 'Entrar com Google'}
          </Button>

          <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex gap-3 text-left">
              <AlertCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-blue-900">
                <p className="font-medium mb-1">Atenção</p>
                <p>
                  Apenas funcionários cadastrados pelo estabelecimento podem acessar esta área.
                </p>
              </div>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
