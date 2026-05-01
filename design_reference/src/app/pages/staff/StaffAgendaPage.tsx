import { useParams, useNavigate, Link } from 'react-router';
import { Calendar, Clock, User, LogOut } from 'lucide-react';
import { AppHeader } from '../../components/AppHeader';
import { Card } from '../../components/ui/card';
import { Badge } from '../../components/ui/badge';
import { getBusinessBySlug, isStaff, setStaffStatus } from '../../lib/auth';

export default function StaffAgendaPage() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const business = getBusinessBySlug(slug || '');
  const staffLoggedIn = isStaff();

  const staffName = 'Pedro Silva';
  
  const upcomingAppointments = [
    {
      id: '1',
      date: '15/03/2026',
      time: '14:00',
      clientName: 'João Silva',
      service: 'Corte + Barba',
      duration: 45,
    },
    {
      id: '2',
      date: '15/03/2026',
      time: '15:00',
      clientName: 'Carlos Souza',
      service: 'Corte Masculino',
      duration: 30,
    },
    {
      id: '3',
      date: '16/03/2026',
      time: '09:00',
      clientName: 'Roberto Lima',
      service: 'Barba',
      duration: 20,
    },
  ];

  const completedAppointments = [
    {
      id: '4',
      date: '14/03/2026',
      time: '10:00',
      clientName: 'André Costa',
      service: 'Corte + Barba',
    },
    {
      id: '5',
      date: '13/03/2026',
      time: '16:30',
      clientName: 'Felipe Santos',
      service: 'Corte Masculino',
    },
  ];

  const handleLogout = () => {
    setStaffStatus(false);
    navigate(`/b/${slug}/funcionario`);
  };

  if (!business) {
    return <div>Estabelecimento não encontrado</div>;
  }

  if (!staffLoggedIn) {
    return (
      <div className="min-h-screen bg-gray-50">
        <AppHeader title={business.name} subtitle="Minha agenda" />
        <div className="flex flex-col items-center justify-center p-8 min-h-[calc(100vh-3.5rem)]">
          <Calendar className="w-16 h-16 text-purple-500 mb-4" />
          <h2 className="text-xl font-semibold mb-2">Faça login para continuar</h2>
          <p className="text-gray-600 mb-6 text-center">
            Você precisa estar logado como funcionário para ver sua agenda
          </p>
          <Link to={`/b/${slug}/funcionario`}>
            <button className="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">
              Fazer login
            </button>
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-6">
      <AppHeader
        title={business.name}
        subtitle="Minha agenda"
        actions={{
          showLogout: true,
          onLogout: handleLogout,
        }}
      />

      <div className="max-w-4xl mx-auto p-4 space-y-6">
        <Card className="p-6">
          <div className="flex items-center gap-4 mb-4">
            <div className="w-16 h-16 bg-gradient-to-br from-purple-600 to-pink-600 rounded-full flex items-center justify-center text-white text-xl font-bold">
              {staffName
                .split(' ')
                .map((n) => n[0])
                .join('')}
            </div>
            <div className="flex-1">
              <h2 className="text-2xl font-bold">Horários com você</h2>
              <p className="text-gray-600">{staffName}</p>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 pt-4 border-t">
            <div className="text-center">
              <div className="text-3xl font-bold text-purple-600">{upcomingAppointments.length}</div>
              <div className="text-sm text-gray-600">Próximos</div>
            </div>
            <div className="text-center">
              <div className="text-3xl font-bold text-gray-400">{completedAppointments.length}</div>
              <div className="text-sm text-gray-600">Realizados (hoje)</div>
            </div>
          </div>
        </Card>

        {upcomingAppointments.length > 0 && (
          <div className="space-y-3">
            <h3 className="text-lg font-semibold flex items-center gap-2">
              <Calendar className="w-5 h-5" />
              Próximos agendamentos
            </h3>
            {upcomingAppointments.map((appointment) => (
              <Card key={appointment.id} className="p-4">
                <div className="flex items-start justify-between mb-3">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
                      <Clock className="w-6 h-6 text-purple-600" />
                    </div>
                    <div>
                      <div className="font-semibold text-lg">
                        {appointment.date} às {appointment.time}
                      </div>
                      <div className="text-sm text-gray-600">
                        {appointment.duration} minutos
                      </div>
                    </div>
                  </div>
                  <Badge>Agendado</Badge>
                </div>

                <div className="space-y-2">
                  <div className="flex items-center gap-2 text-sm">
                    <User className="w-4 h-4 text-gray-400" />
                    <span className="font-medium">{appointment.clientName}</span>
                  </div>
                  <div className="text-sm text-gray-600">
                    <span className="font-medium">Serviço:</span> {appointment.service}
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}

        {completedAppointments.length > 0 && (
          <div className="space-y-3">
            <h3 className="text-lg font-semibold">Realizados</h3>
            {completedAppointments.map((appointment) => (
              <Card key={appointment.id} className="p-4 opacity-75">
                <div className="flex items-start justify-between">
                  <div>
                    <div className="font-semibold">
                      {appointment.date} às {appointment.time}
                    </div>
                    <div className="text-sm text-gray-600 mt-1">
                      {appointment.clientName} • {appointment.service}
                    </div>
                  </div>
                  <Badge variant="outline">Concluído</Badge>
                </div>
              </Card>
            ))}
          </div>
        )}

        {upcomingAppointments.length === 0 && (
          <Card className="p-8 text-center">
            <Calendar className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold mb-2">Nenhum horário marcado com você</h3>
            <p className="text-gray-600">
              Quando tiver agendamentos, eles aparecerão aqui.
            </p>
          </Card>
        )}
      </div>
    </div>
  );
}
