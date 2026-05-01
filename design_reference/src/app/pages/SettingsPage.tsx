import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { AppHeader } from '../components/AppHeader';
import { Card } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Button } from '../components/ui/button';
import { getCurrentUser, getUserBusiness, saveBusiness } from '../lib/auth';
import { toast } from 'sonner';

export default function SettingsPage() {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [primaryColor, setPrimaryColor] = useState('#8B5CF6');
  const [secondaryColor, setSecondaryColor] = useState('#EC4899');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const user = getCurrentUser();
    if (!user) {
      navigate('/login');
      return;
    }

    const business = getUserBusiness(user.uid);
    if (business) {
      setName(business.name);
      setSlug(business.slug);
      setPrimaryColor(business.primaryColor);
      setSecondaryColor(business.secondaryColor);
    }
  }, [navigate]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const user = getCurrentUser();
      if (!user) throw new Error('Usuário não autenticado');

      const business = {
        id: 'biz-' + Date.now(),
        name,
        slug: slug.toLowerCase().replace(/[^a-z0-9-]/g, ''),
        ownerId: user.uid,
        primaryColor,
        secondaryColor,
        trialEndDate: '2026-04-14',
        subscriptionStatus: 'trial' as const,
      };

      saveBusiness(business);
      toast.success('Configurações salvas com sucesso!');
      setTimeout(() => navigate('/dashboard'), 1000);
    } catch (error) {
      toast.error('Erro ao salvar configurações');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <AppHeader title="Configurações" subtitle="Configure seu negócio" showBack />

      <div className="max-w-2xl mx-auto p-4">
        <Card className="p-6">
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="name">Nome do estabelecimento</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Ex: Barbearia Moderna"
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="slug">Slug (link personalizado)</Label>
              <div className="flex items-center gap-2">
                <span className="text-sm text-gray-600">meunegocio.app/b/</span>
                <Input
                  id="slug"
                  value={slug}
                  onChange={(e) => setSlug(e.target.value.toLowerCase())}
                  placeholder="moderna"
                  pattern="[a-z0-9-]+"
                  required
                  className="flex-1"
                />
              </div>
              <p className="text-xs text-gray-500">
                Apenas letras minúsculas, números e hífens
              </p>
            </div>

            <div className="grid sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="primaryColor">Cor primária</Label>
                <div className="flex gap-2">
                  <Input
                    id="primaryColor"
                    type="color"
                    value={primaryColor}
                    onChange={(e) => setPrimaryColor(e.target.value)}
                    className="w-20 h-10"
                  />
                  <Input
                    value={primaryColor}
                    onChange={(e) => setPrimaryColor(e.target.value)}
                    placeholder="#8B5CF6"
                    className="flex-1"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="secondaryColor">Cor secundária</Label>
                <div className="flex gap-2">
                  <Input
                    id="secondaryColor"
                    type="color"
                    value={secondaryColor}
                    onChange={(e) => setSecondaryColor(e.target.value)}
                    className="w-20 h-10"
                  />
                  <Input
                    value={secondaryColor}
                    onChange={(e) => setSecondaryColor(e.target.value)}
                    placeholder="#EC4899"
                    className="flex-1"
                  />
                </div>
              </div>
            </div>

            <div className="space-y-2">
              <Label>Logo (em breve)</Label>
              <div className="border-2 border-dashed rounded-lg p-8 text-center text-gray-400">
                Upload de logo em desenvolvimento
              </div>
            </div>

            <div className="space-y-2">
              <Label>Imagem de fundo (em breve)</Label>
              <div className="border-2 border-dashed rounded-lg p-8 text-center text-gray-400">
                Upload de imagem de fundo em desenvolvimento
              </div>
            </div>

            <div className="flex gap-3 pt-4">
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => navigate('/dashboard')}
              >
                Cancelar
              </Button>
              <Button type="submit" className="flex-1" disabled={loading}>
                {loading ? 'Salvando...' : 'Salvar configurações'}
              </Button>
            </div>
          </form>
        </Card>
      </div>
    </div>
  );
}
