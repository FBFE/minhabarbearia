import { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router';
import { UserPlus } from 'lucide-react';
import { Card } from '../../components/ui/card';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Button } from '../../components/ui/button';
import { Checkbox } from '../../components/ui/checkbox';
import { getBusinessBySlug, clientRegister } from '../../lib/auth';
import { toast } from 'sonner';

export default function ClientRegisterPage() {
  const { slug } = useParams();
  const navigate = useNavigate();
  const business = getBusinessBySlug(slug || '');

  const [formData, setFormData] = useState({
    name: '',
    birthDate: '',
    phone: '',
    email: '',
    cpf: '',
    password: '',
    referredBy: '',
    acceptedTerms: false,
    cardStyle: 'masculine',
  });
  const [loading, setLoading] = useState(false);

  const handleChange = (field: string, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.acceptedTerms) {
      toast.error('Você precisa aceitar os termos da LGPD');
      return;
    }

    setLoading(true);

    try {
      await clientRegister({
        businessId: business?.id || '',
        name: formData.name,
        email: formData.email,
        phone: formData.phone,
        birthDate: formData.birthDate,
      });
      toast.success('Cadastro realizado com sucesso!');
      navigate(`/b/${slug}/perfil`);
    } catch (error) {
      toast.error('Erro ao realizar cadastro');
    } finally {
      setLoading(false);
    }
  };

  if (!business) {
    return <div>Estabelecimento não encontrado</div>;
  }

  return (
    <div className="min-h-screen bg-gray-50 py-6">
      <div className="max-w-2xl mx-auto p-4">
        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-purple-600 rounded-full mb-3">
            <UserPlus className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-3xl font-bold mb-2">Criar cadastro</h1>
          <p className="text-gray-600">{business.name}</p>
        </div>

        <Card className="p-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">Nome completo *</Label>
              <Input
                id="name"
                value={formData.name}
                onChange={(e) => handleChange('name', e.target.value)}
                placeholder="Seu nome"
                required
              />
            </div>

            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="birthDate">Data de nascimento *</Label>
                <Input
                  id="birthDate"
                  type="date"
                  value={formData.birthDate}
                  onChange={(e) => handleChange('birthDate', e.target.value)}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="phone">WhatsApp *</Label>
                <Input
                  id="phone"
                  type="tel"
                  value={formData.phone}
                  onChange={(e) => handleChange('phone', e.target.value)}
                  placeholder="(11) 98765-4321"
                  required
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="email">E-mail *</Label>
              <Input
                id="email"
                type="email"
                value={formData.email}
                onChange={(e) => handleChange('email', e.target.value)}
                placeholder="seu@email.com"
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="cpf">CPF (opcional)</Label>
              <Input
                id="cpf"
                value={formData.cpf}
                onChange={(e) => handleChange('cpf', e.target.value)}
                placeholder="000.000.000-00"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="password">Senha *</Label>
              <Input
                id="password"
                type="password"
                value={formData.password}
                onChange={(e) => handleChange('password', e.target.value)}
                placeholder="Mínimo 6 caracteres"
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="referredBy">Quem te indicou?</Label>
              <Input
                id="referredBy"
                value={formData.referredBy}
                onChange={(e) => handleChange('referredBy', e.target.value)}
                placeholder="Nome de quem indicou (opcional)"
              />
            </div>

            <div className="space-y-3 pt-4 border-t">
              <div className="flex items-start gap-3">
                <Checkbox
                  id="terms"
                  checked={formData.acceptedTerms}
                  onCheckedChange={(checked) => handleChange('acceptedTerms', checked)}
                />
                <label htmlFor="terms" className="text-sm text-gray-700 leading-tight cursor-pointer">
                  Li e aceito os termos de uso e política de privacidade (LGPD) *
                </label>
              </div>

              <div className="space-y-2">
                <Label>Estilo do cartão fidelidade</Label>
                <div className="flex gap-3">
                  <Button
                    type="button"
                    variant={formData.cardStyle === 'masculine' ? 'default' : 'outline'}
                    className="flex-1"
                    onClick={() => handleChange('cardStyle', 'masculine')}
                  >
                    Masculino
                  </Button>
                  <Button
                    type="button"
                    variant={formData.cardStyle === 'feminine' ? 'default' : 'outline'}
                    className="flex-1"
                    onClick={() => handleChange('cardStyle', 'feminine')}
                  >
                    Feminino
                  </Button>
                </div>
              </div>
            </div>

            <Button type="submit" className="w-full" disabled={loading}>
              {loading ? 'Cadastrando...' : 'Cadastrar'}
            </Button>
          </form>
        </Card>

        <p className="text-center text-sm text-gray-600 mt-4">
          Já tem conta?{' '}
          <Link to={`/b/${slug}/login`} className="text-purple-600 hover:underline font-medium">
            Entrar
          </Link>
        </p>
      </div>
    </div>
  );
}
