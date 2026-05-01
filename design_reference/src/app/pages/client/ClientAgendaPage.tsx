import { useParams, Link } from 'react-router';
import { Calendar, Clock, User, AlertCircle } from 'lucide-react';
import { AppHeader } from '../../components/AppHeader';
import { BottomNav } from '../../components/BottomNav';
import { Card } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { Badge } from '../../components/ui/badge';
import { Progress } from '../../components/ui/progress';
import { getBusinessBySlug, getClientData } from '../../lib/auth';

export default function ClientAgendaPage() {
  const { slug } = useParams();
  const business = getBusinessBySlug(slug || '');
  const client = getClientData();

  const appointments = [
    {
      id: '1',
      date: '15/03/2026',
      time: '14:00',
      service: 'Corte + Barba',
      staff: 'Pedro',
      status: 'confirmado',
      progress: 50,
    },
    {
      id: '2',
      date: '10/03/2026',
      time: '10:30',
      service: 'Corte Masculino',
      staff: 'Ana',
      status: 'realizado',
      progress: 100,
    },
  ];

  const upcoming = appointments.filter((a) => a.status !== 'realizado');
  const history = appointments.filter((a) => a.status === 'realizado');

  if (!business) {
    return <div>Estabelecimento não encontrado</div>;
  }

  if (!client) {
    return (
      <div className="min-h-screen bg-gray-50">
        <AppHeader title={business.name} subtitle="Acompanhe seus agendamentos" />
        <div className="flex flex-col items-center justify-center p-8 min-h-[calc(100vh-3.5rem)]">
          <AlertCircle className="w-16 h-16 text-purple-500 mb-4" />
          <h2 className="text-xl font-semibold mb-2">Verifique seu cadastro</h2>
          <p className="text-gray-600 mb-6 text-center">
            Faça login para ver seus agendamentos
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
      <AppHeader title={business.name} subtitle="Acompanhe seus agendamentos" />

      <div className="max-w-2xl mx-auto p-4 space-y-6">
        {upcoming.length === 0 && history.length === 0 ? (
          <Card className="p-8 text-center">
            <Calendar className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold mb-2">Nenhum agendamento</h3>
            <p className="text-gray-600 mb-6">
              Você ainda não tem agendamentos. Que tal agendar seu próximo horário?
            </p>
            <Link to={`/b/${slug}`}>
              <Button>Agendar horário</Button>
            </Link>
          </Card>
        ) : (
          <>
            {upcoming.length > 0 && (
              <div className="space-y-3">
                <h2 className="text-xl font-semibold">Agendados</h2>
                {upcoming.map((appointment) => (
                  <Card key={appointment.id} className="p-4">
                    <div className="flex items-start justify-between mb-3">
                      <div>
                        <div className="font-semibold text-lg">
                          {appointment.date} às {appointment.time}
                        </div>
                        <div className="text-sm text-gray-600">{appointment.service}</div>
                      </div>
                      <Badge>{appointment.status}</Badge>
                    </div>

                    <div className="mb-3">
                      <div className="flex justify-between text-xs text-gray-600 mb-1">
                        <span>Agendado</span>
                        <span>Confirmado</span>
                        <span>Realizado</span>
                      </div>
                      <Progress value={appointment.progress} />
                    </div>

                    <div className="flex items-center gap-2 text-sm text-gray-600 mb-3">
                      <User className="w-4 h-4" />
                      <span>Profissional: {appointment.staff}</span>
                    </div>

                    <div className="flex gap-2">
                      <Button size="sm" variant="outline" className="flex-1">
                        Reagendar
                      </Button>
                      <Button size="sm" variant="outline" className="flex-1">
                        Cancelar
                      </Button>
                    </div>
                  </Card>
                ))}
              </div>
            )}

            {history.length > 0 && (
              <div className="space-y-3">
                <h2 className="text-xl font-semibold">Histórico</h2>
                {history.map((appointment) => (
                  <Card key={appointment.id} className="p-4 opacity-75">
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <div className="font-semibold">
                          {appointment.date} às {appointment.time}
                        </div>
                        <div className="text-sm text-gray-600">{appointment.service}</div>
                      </div>
                      <Badge variant="outline">{appointment.status}</Badge>
                    </div>

                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <User className="w-4 h-4" />
                      <span>Profissional: {appointment.staff}</span>
                    </div>
                  </Card>
                ))}
              </div>
            )}
          </>
        )}
      </div>

      <BottomNav type="client" slug={slug} />
    </div>
  );
}
