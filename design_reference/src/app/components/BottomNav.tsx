import { Link, useLocation } from 'react-router';
import { Home, Calendar, Gift, User, BarChart, Users, Package, ClipboardList } from 'lucide-react';

interface BottomNavProps {
  type: 'client' | 'dashboard';
  slug?: string;
}

export function BottomNav({ type, slug }: BottomNavProps) {
  const location = useLocation();

  if (type === 'client' && slug) {
    const clientLinks = [
      { path: `/b/${slug}`, icon: Home, label: 'Início' },
      { path: `/b/${slug}/agenda`, icon: Calendar, label: 'Agenda' },
      { path: `/b/${slug}/fidelidade`, icon: Gift, label: 'Fidelidade' },
      { path: `/b/${slug}/perfil`, icon: User, label: 'Perfil' },
    ];

    return (
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 z-50 safe-area-inset-bottom">
        <div className="flex justify-around items-center h-16 max-w-screen-xl mx-auto px-2">
          {clientLinks.map((link) => {
            const Icon = link.icon;
            const isActive = location.pathname === link.path;
            return (
              <Link
                key={link.path}
                to={link.path}
                className={`flex flex-col items-center justify-center flex-1 h-full gap-1 transition-colors ${
                  isActive ? 'text-purple-600' : 'text-gray-600 hover:text-purple-500'
                }`}
              >
                <Icon className="w-5 h-5" />
                <span className="text-xs">{link.label}</span>
              </Link>
            );
          })}
        </div>
      </nav>
    );
  }

  if (type === 'dashboard') {
    const dashboardTabs = [
      { id: 'inicio', icon: Home, label: 'Início' },
      { id: 'agenda', icon: Calendar, label: 'Agenda' },
      { id: 'servicos', icon: ClipboardList, label: 'Serviços' },
      { id: 'clientes', icon: Users, label: 'Clientes' },
      { id: 'estoque', icon: Package, label: 'Estoque' },
      { id: 'relatorios', icon: BarChart, label: 'Relatórios' },
    ];

    return (
      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 z-50 safe-area-inset-bottom">
        <div className="flex justify-around items-center h-16 max-w-screen-xl mx-auto px-1">
          {dashboardTabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = location.hash === `#${tab.id}` || (!location.hash && tab.id === 'inicio');
            return (
              <a
                key={tab.id}
                href={`#${tab.id}`}
                className={`flex flex-col items-center justify-center flex-1 h-full gap-0.5 transition-colors ${
                  isActive ? 'text-purple-600' : 'text-gray-600 hover:text-purple-500'
                }`}
              >
                <Icon className="w-5 h-5" />
                <span className="text-[10px] leading-tight text-center">{tab.label}</span>
              </a>
            );
          })}
        </div>
      </nav>
    );
  }

  return null;
}
