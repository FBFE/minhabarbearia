import { useState } from 'react';
import { Calendar as CalendarIcon, Clock, User, Scissors } from 'lucide-react';
import { Card } from '../ui/card';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Calendar } from '../ui/calendar';

interface Appointment {
  id: string;
  time: string;
  clientName: string;
  service: string;
  staff: string;
  status: 'agendado' | 'confirmado' | 'realizado' | 'cancelado';
}

export function DashboardAgenda() {
  const [selectedDate, setSelectedDate] = useState<Date | undefined>(new Date());

  const appointments: Appointment[] = [
    {
      id: '1',
      time: '09:00',
      clientName: 'João Silva',
      service: 'Corte + Barba',
      staff: 'Pedro',
      status: 'confirmado',
    },
    {
      id: '2',
      time: '10:30',
      clientName: 'Maria Santos',
      service: 'Corte',
      staff: 'Ana',
      status: 'agendado',
    },
    {
      id: '3',
      time: '14:00',
      clientName: 'Carlos Souza',
      service: 'Barba',
      staff: 'Pedro',
      status: 'agendado',
    },
  ];

  const getStatusBadge = (status: string) => {
    const variants = {
      agendado: { variant: 'secondary' as const, label: 'Agendado' },
      confirmado: { variant: 'default' as const, label: 'Confirmado' },
      realizado: { variant: 'outline' as const, label: 'Realizado' },
      cancelado: { variant: 'destructive' as const, label: 'Cancelado' },
    };
    const config = variants[status as keyof typeof variants] || variants.agendado;
    return <Badge variant={config.variant}>{config.label}</Badge>;
  };

  return (
    <div className="space-y-4">
      <Card className="p-4">
        <div className="flex justify-center">
          <Calendar
            mode="single"
            selected={selectedDate}
            onSelect={setSelectedDate}
            className="rounded-md border"
          />
        </div>
      </Card>

      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold">
            Agendamentos de {selectedDate?.toLocaleDateString('pt-BR')}
          </h3>
          <Badge>{appointments.length} agendamentos</Badge>
        </div>

        {appointments.map((appointment) => (
          <Card key={appointment.id} className="p-4">
            <div className="flex items-start justify-between gap-4 mb-3">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
                  <Clock className="w-6 h-6 text-purple-600" />
                </div>
                <div>
                  <div className="font-semibold text-lg">{appointment.time}</div>
                  <div className="text-sm text-gray-600">{appointment.clientName}</div>
                </div>
              </div>
              {getStatusBadge(appointment.status)}
            </div>

            <div className="grid grid-cols-2 gap-3 text-sm mb-3">
              <div className="flex items-center gap-2 text-gray-600">
                <Scissors className="w-4 h-4" />
                <span>{appointment.service}</span>
              </div>
              <div className="flex items-center gap-2 text-gray-600">
                <User className="w-4 h-4" />
                <span>{appointment.staff}</span>
              </div>
            </div>

            <div className="flex gap-2">
              <Button size="sm" variant="outline" className="flex-1">
                Detalhes
              </Button>
              <Button size="sm" variant="outline" className="flex-1">
                Reagendar
              </Button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
