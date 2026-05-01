import { useState } from 'react';
import { Search, User, Phone, Calendar, Eye } from 'lucide-react';
import { Card } from '../ui/card';
import { Input } from '../ui/input';
import { Button } from '../ui/button';
import { Avatar, AvatarFallback } from '../ui/avatar';

interface Client {
  id: string;
  name: string;
  phone: string;
  birthDate: string;
  totalAppointments: number;
  lastVisit: string;
}

export function DashboardClients() {
  const [searchTerm, setSearchTerm] = useState('');

  const clients: Client[] = [
    {
      id: '1',
      name: 'João Silva',
      phone: '(11) 98765-4321',
      birthDate: '15/03/1990',
      totalAppointments: 24,
      lastVisit: '10/03/2026',
    },
    {
      id: '2',
      name: 'Maria Santos',
      phone: '(11) 97654-3210',
      birthDate: '22/07/1985',
      totalAppointments: 18,
      lastVisit: '12/03/2026',
    },
    {
      id: '3',
      name: 'Carlos Souza',
      phone: '(11) 96543-2109',
      birthDate: '08/11/1992',
      totalAppointments: 32,
      lastVisit: '14/03/2026',
    },
    {
      id: '4',
      name: 'Ana Paula',
      phone: '(11) 95432-1098',
      birthDate: '30/01/1988',
      totalAppointments: 15,
      lastVisit: '08/03/2026',
    },
  ];

  const filteredClients = clients.filter((client) =>
    client.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    client.phone.includes(searchTerm)
  );

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            placeholder="Buscar por nome ou telefone..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-600">
          {filteredClients.length} {filteredClients.length === 1 ? 'cliente' : 'clientes'}
        </p>
      </div>

      <div className="space-y-3">
        {filteredClients.map((client) => (
          <Card key={client.id} className="p-4">
            <div className="flex items-start gap-4">
              <Avatar className="w-12 h-12 bg-purple-600 text-white">
                <AvatarFallback>{getInitials(client.name)}</AvatarFallback>
              </Avatar>

              <div className="flex-1 min-w-0">
                <h3 className="font-semibold mb-1">{client.name}</h3>

                <div className="space-y-1 text-sm text-gray-600 mb-3">
                  <div className="flex items-center gap-2">
                    <Phone className="w-3 h-3" />
                    <span>{client.phone}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Calendar className="w-3 h-3" />
                    <span>Nascimento: {client.birthDate}</span>
                  </div>
                </div>

                <div className="flex items-center gap-4 text-xs">
                  <div>
                    <span className="font-semibold text-purple-600">{client.totalAppointments}</span>
                    <span className="text-gray-600"> agendamentos</span>
                  </div>
                  <div>
                    <span className="text-gray-600">Última visita: </span>
                    <span className="font-medium">{client.lastVisit}</span>
                  </div>
                </div>
              </div>

              <Button size="sm" variant="outline">
                <Eye className="w-4 h-4" />
              </Button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
