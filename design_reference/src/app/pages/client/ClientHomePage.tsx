import { useState } from 'react';
import { useParams } from 'react-router';
import { Clock, MapPin, Phone } from 'lucide-react';
import { AppHeader } from '../../components/AppHeader';
import { Card } from '../../components/ui/card';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Checkbox } from '../../components/ui/checkbox';
import { getBusinessBySlug } from '../../lib/auth';

export default function ClientHomePage() {
  const { slug } = useParams();
  const business = getBusinessBySlug(slug || '');
  const [step, setStep] = useState<'verification' | 'services' | 'staff' | 'datetime' | 'confirm'>('verification');
  const [phone, setPhone] = useState('');
  const [birthDate, setBirthDate] = useState('');
  const [selectedServices, setSelectedServices] = useState<string[]>([]);

  const services = [
    { id: '1', name: 'Corte Masculino', duration: 30, price: 40 },
    { id: '2', name: 'Barba', duration: 20, price: 25 },
    { id: '3', name: 'Corte + Barba', duration: 45, price: 60 },
    { id: '4', name: 'Sobrancelha', duration: 15, price: 15 },
  ];

  const handleVerification = (e: React.FormEvent) => {
    e.preventDefault();
    setStep('services');
  };

  const toggleService = (serviceId: string) => {
    setSelectedServices((prev) =>
      prev.includes(serviceId)
        ? prev.filter((id) => id !== serviceId)
        : [...prev, serviceId]
    );
  };

  if (!business) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <Card className="p-6 text-center">
          <h2 className="text-xl font-semibold mb-2">Estabelecimento não encontrado</h2>
          <p className="text-gray-600">O link que você acessou não é válido.</p>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-6">
      <AppHeader title={business.name} subtitle="Agende seu horário" />

      <div className="max-w-2xl mx-auto p-4 space-y-4">
        <div
          className="h-48 rounded-lg bg-cover bg-center relative overflow-hidden"
          style={{
            backgroundImage: `linear-gradient(to bottom, ${business.primaryColor}aa, ${business.secondaryColor}aa), url('https://images.unsplash.com/photo-1759134198561-e2041049419c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtb2Rlcm4lMjBiYXJiZXJzaG9wJTIwc2Fsb258ZW58MXx8fHwxNzczNTExNDM1fDA&ixlib=rb-4.1.0&q=80&w=1080')`,
          }}
        >
          <div className="absolute inset-0 flex flex-col justify-end p-6 text-white">
            <h1 className="text-3xl font-bold mb-2">{business.name}</h1>
            <p className="text-white/90">Barbearia</p>
          </div>
        </div>

        <Card className="p-4">
          <div className="space-y-3 text-sm">
            <div className="flex items-center gap-3 text-gray-600">
              <Clock className="w-5 h-5" />
              <span>Seg - Sex: 9h às 19h | Sáb: 9h às 17h</span>
            </div>
            <div className="flex items-center gap-3 text-gray-600">
              <MapPin className="w-5 h-5" />
              <span>Rua Exemplo, 123 - Centro</span>
            </div>
            <div className="flex items-center gap-3 text-gray-600">
              <Phone className="w-5 h-5" />
              <span>(11) 98765-4321</span>
            </div>
          </div>
        </Card>

        {step === 'verification' && (
          <Card className="p-6">
            <h2 className="text-xl font-semibold mb-4">Verificação</h2>
            <form onSubmit={handleVerification} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="phone">WhatsApp</Label>
                <Input
                  id="phone"
                  type="tel"
                  placeholder="(11) 98765-4321"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="birthDate">Data de nascimento</Label>
                <Input
                  id="birthDate"
                  type="date"
                  value={birthDate}
                  onChange={(e) => setBirthDate(e.target.value)}
                  required
                />
              </div>

              <Button type="submit" className="w-full">
                Continuar
              </Button>

              <p className="text-xs text-center text-gray-600">
                Já tem cadastro? Faremos a verificação automaticamente.
              </p>
            </form>
          </Card>
        )}

        {step === 'services' && (
          <Card className="p-6">
            <h2 className="text-xl font-semibold mb-4">Escolha os serviços</h2>
            <div className="space-y-3 mb-6">
              {services.map((service) => (
                <div
                  key={service.id}
                  className="flex items-center gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50"
                  onClick={() => toggleService(service.id)}
                >
                  <Checkbox checked={selectedServices.includes(service.id)} />
                  <div className="flex-1">
                    <div className="font-medium">{service.name}</div>
                    <div className="text-sm text-gray-600">
                      {service.duration} min • R$ {service.price.toFixed(2)}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="flex gap-3">
              <Button variant="outline" className="flex-1" onClick={() => setStep('verification')}>
                Voltar
              </Button>
              <Button
                className="flex-1"
                disabled={selectedServices.length === 0}
                onClick={() => setStep('staff')}
              >
                Continuar
              </Button>
            </div>
          </Card>
        )}

        {step === 'staff' && (
          <Card className="p-6">
            <h2 className="text-xl font-semibold mb-4">Escolha o profissional</h2>
            <div className="space-y-3 mb-6">
              {['Pedro', 'Ana', 'Carlos'].map((staff) => (
                <Button key={staff} variant="outline" className="w-full justify-start">
                  {staff}
                </Button>
              ))}
              <Button variant="outline" className="w-full">
                Sem preferência
              </Button>
            </div>

            <div className="flex gap-3">
              <Button variant="outline" className="flex-1" onClick={() => setStep('services')}>
                Voltar
              </Button>
              <Button className="flex-1" onClick={() => setStep('datetime')}>
                Continuar
              </Button>
            </div>
          </Card>
        )}

        {step === 'datetime' && (
          <Card className="p-6">
            <h2 className="text-xl font-semibold mb-4">Data e horário</h2>
            <p className="text-center text-gray-600 py-8">
              Calendário e slots de horário disponíveis
            </p>
            <div className="flex gap-3">
              <Button variant="outline" className="flex-1" onClick={() => setStep('staff')}>
                Voltar
              </Button>
              <Button className="flex-1" onClick={() => setStep('confirm')}>
                Confirmar agendamento
              </Button>
            </div>
          </Card>
        )}

        {step === 'confirm' && (
          <Card className="p-6 text-center">
            <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <Clock className="w-8 h-8 text-green-600" />
            </div>
            <h2 className="text-2xl font-semibold mb-2">Agendamento confirmado!</h2>
            <p className="text-gray-600 mb-6">
              Seu horário foi reservado. Você receberá uma confirmação no WhatsApp.
            </p>
            <Button onClick={() => setStep('verification')} className="w-full">
              Fazer outro agendamento
            </Button>
          </Card>
        )}
      </div>
    </div>
  );
}
