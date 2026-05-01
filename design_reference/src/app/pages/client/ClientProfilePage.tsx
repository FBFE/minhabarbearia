import { useParams, Link } from 'react-router';
import { User, Phone, Calendar, MapPin, Gift, Award, AlertCircle } from 'lucide-react';
import { AppHeader } from '../../components/AppHeader';
import { BottomNav } from '../../components/BottomNav';
import { Card } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { Avatar, AvatarFallback } from '../../components/ui/avatar';
import { getBusinessBySlug, getClientData } from '../../lib/auth';

export default function ClientProfilePage() {
  const { slug } = useParams();
  const business = getBusinessBySlug(slug || '');
  const client = getClientData();

  const history = [
    { id: '1', service: 'Corte + Barba', date: '10/03/2026', staff: 'Pedro' },
    { id: '2', service: 'Corte Masculino', date: '05/03/2026', staff: 'Ana' },
    { id: '3', service: 'Corte + Barba', date: '28/02/2026', staff: 'Pedro' },
  ];

  if (!business) {
    return <div>Estabelecimento não encontrado</div>;
  }

  if (!client) {
    return (
      <div className="min-h-screen bg-gray-50">
        <AppHeader title={business.name} subtitle="Seu perfil" />
        <div className="flex flex-col items-center justify-center p-8 min-h-[calc(100vh-3.5rem)]">
          <AlertCircle className="w-16 h-16 text-purple-500 mb-4" />
          <h2 className="text-xl font-semibold mb-2">Verifique seu cadastro</h2>
          <p className="text-gray-600 mb-6 text-center">
            Faça login para ver seu perfil
          </p>
          <Link to={`/b/${slug}`}>
            <Button>Ir para página inicial</Button>
          </Link>
        </div>
        <BottomNav type="client" slug={slug} />
      </div>
    );
  }

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <AppHeader title={business.name} subtitle="Seu perfil" />

      <div className="max-w-2xl mx-auto p-4 space-y-4">
        <Card className="p-6">
          <div className="flex flex-col items-center text-center mb-6">
            <Avatar className="w-24 h-24 bg-gradient-to-br from-purple-600 to-pink-600 text-white text-2xl mb-4">
              <AvatarFallback>{getInitials(client.name)}</AvatarFallback>
            </Avatar>
            <h2 className="text-2xl font-bold">{client.name}</h2>
          </div>

          <div className="space-y-3 mb-6">
            <div className="flex items-center gap-3 py-2 border-b">
              <Phone className="w-5 h-5 text-gray-400" />
              <div className="flex-1">
                <div className="text-xs text-gray-600">WhatsApp</div>
                <div className="font-medium">{client.phone}</div>
              </div>
            </div>

            {client.birthDate && (
              <div className="flex items-center gap-3 py-2 border-b">
                <Calendar className="w-5 h-5 text-gray-400" />
                <div className="flex-1">
                  <div className="text-xs text-gray-600">Data de nascimento</div>
                  <div className="font-medium">{client.birthDate}</div>
                </div>
              </div>
            )}

            <div className="flex items-center gap-3 py-2 border-b">
              <Gift className="w-5 h-5 text-gray-400" />
              <div className="flex-1">
                <div className="text-xs text-gray-600">Selos de fidelidade</div>
                <div className="font-medium">{client.stamps} selos</div>
              </div>
            </div>

            <div className="flex items-center gap-3 py-2">
              <Award className="w-5 h-5 text-gray-400" />
              <div className="flex-1">
                <div className="text-xs text-gray-600">Total de agendamentos</div>
                <div className="font-medium">{client.totalAppointments} atendimentos</div>
              </div>
            </div>
          </div>

          <Link to={`/b/${slug}`}>
            <Button className="w-full">Agendar horário</Button>
          </Link>
        </Card>

        <div className="space-y-3">
          <h3 className="text-lg font-semibold">O que você já fez aqui</h3>
          {history.map((item) => (
            <Card key={item.id} className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-medium">{item.service}</div>
                  <div className="text-sm text-gray-600">
                    {item.date} • Com {item.staff}
                  </div>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </div>

      <BottomNav type="client" slug={slug} />
    </div>
  );
}
