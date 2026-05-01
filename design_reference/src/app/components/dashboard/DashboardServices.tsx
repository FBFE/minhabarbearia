import { useState } from 'react';
import { Plus, Scissors, Clock, DollarSign, Pencil, Trash2 } from 'lucide-react';
import { Card } from '../ui/card';
import { Button } from '../ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '../ui/dialog';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Textarea } from '../ui/textarea';

interface Service {
  id: string;
  name: string;
  duration: number;
  price: number;
  description?: string;
}

export function DashboardServices() {
  const [services, setServices] = useState<Service[]>([
    { id: '1', name: 'Corte Masculino', duration: 30, price: 40, description: 'Corte tradicional ou moderno' },
    { id: '2', name: 'Barba', duration: 20, price: 25, description: 'Design de barba completo' },
    { id: '3', name: 'Corte + Barba', duration: 45, price: 60, description: 'Combo completo' },
  ]);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingService, setEditingService] = useState<Service | null>(null);

  const handleAddService = (newService: Omit<Service, 'id'>) => {
    setServices([...services, { ...newService, id: Date.now().toString() }]);
    setDialogOpen(false);
  };

  const handleDelete = (id: string) => {
    if (confirm('Deseja realmente excluir este serviço?')) {
      setServices(services.filter((s) => s.id !== id));
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">Serviços</h2>
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="w-4 h-4 mr-2" />
              Adicionar serviço
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Novo serviço</DialogTitle>
            </DialogHeader>
            <ServiceForm onSubmit={handleAddService} />
          </DialogContent>
        </Dialog>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {services.map((service) => (
          <Card key={service.id} className="p-4">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-start gap-3 flex-1">
                <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center flex-shrink-0">
                  <Scissors className="w-5 h-5 text-purple-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold truncate">{service.name}</h3>
                  {service.description && (
                    <p className="text-sm text-gray-600 line-clamp-2">{service.description}</p>
                  )}
                </div>
              </div>
            </div>

            <div className="flex items-center gap-4 mb-3 text-sm">
              <div className="flex items-center gap-1 text-gray-600">
                <Clock className="w-4 h-4" />
                <span>{service.duration} min</span>
              </div>
              <div className="flex items-center gap-1 text-purple-600 font-semibold">
                <DollarSign className="w-4 h-4" />
                <span>R$ {service.price.toFixed(2)}</span>
              </div>
            </div>

            <div className="flex gap-2">
              <Button size="sm" variant="outline" className="flex-1">
                <Pencil className="w-3 h-3 mr-1" />
                Editar
              </Button>
              <Button
                size="sm"
                variant="outline"
                className="flex-1 text-red-600 hover:bg-red-50"
                onClick={() => handleDelete(service.id)}
              >
                <Trash2 className="w-3 h-3 mr-1" />
                Excluir
              </Button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

function ServiceForm({ onSubmit }: { onSubmit: (service: Omit<Service, 'id'>) => void }) {
  const [name, setName] = useState('');
  const [duration, setDuration] = useState('30');
  const [price, setPrice] = useState('');
  const [description, setDescription] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit({
      name,
      duration: parseInt(duration),
      price: parseFloat(price),
      description,
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="name">Nome do serviço</Label>
        <Input
          id="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Ex: Corte Masculino"
          required
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label htmlFor="duration">Duração (min)</Label>
          <Input
            id="duration"
            type="number"
            value={duration}
            onChange={(e) => setDuration(e.target.value)}
            min="5"
            step="5"
            required
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="price">Preço (R$)</Label>
          <Input
            id="price"
            type="number"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            min="0"
            step="0.01"
            placeholder="0.00"
            required
          />
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="description">Descrição (opcional)</Label>
        <Textarea
          id="description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Descreva o serviço..."
          rows={3}
        />
      </div>

      <Button type="submit" className="w-full">
        Adicionar serviço
      </Button>
    </form>
  );
}
