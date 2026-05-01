import { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router';
import { AppHeader } from '../components/AppHeader';
import { BottomNav } from '../components/BottomNav';
import { getCurrentUser, getUserBusiness, logout, isAdmin, mockBusiness, saveBusiness } from '../lib/auth';
import { DashboardHome } from '../components/dashboard/DashboardHome';
import { DashboardAgenda } from '../components/dashboard/DashboardAgenda';
import { DashboardServices } from '../components/dashboard/DashboardServices';
import { DashboardClients } from '../components/dashboard/DashboardClients';
import { DashboardStock } from '../components/dashboard/DashboardStock';
import { DashboardReports } from '../components/dashboard/DashboardReports';

const tabs = [
  { id: 'inicio', label: 'Início' },
  { id: 'agenda', label: 'Agenda' },
  { id: 'servicos', label: 'Serviços' },
  { id: 'clientes', label: 'Clientes' },
  { id: 'estoque', label: 'Estoque' },
  { id: 'relatorios', label: 'Relatórios' },
];

export default function DashboardPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [user, setUser] = useState(getCurrentUser());
  const [business, setBusiness] = useState(getUserBusiness(user?.uid || ''));

  useEffect(() => {
    const currentUser = getCurrentUser();
    if (!currentUser) {
      navigate('/login');
      return;
    }
    setUser(currentUser);

    // Initialize mock business if none exists
    let userBusiness = getUserBusiness(currentUser.uid);
    if (!userBusiness) {
      userBusiness = { ...mockBusiness, ownerId: currentUser.uid };
      saveBusiness(userBusiness);
    }
    setBusiness(userBusiness);
  }, [navigate]);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const getCurrentTab = () => {
    const hash = location.hash.replace('#', '');
    return hash || 'inicio';
  };

  const currentTab = getCurrentTab();
  const tabLabel = tabs.find((t) => t.id === currentTab)?.label || 'Dashboard';

  const renderTabContent = () => {
    switch (currentTab) {
      case 'inicio':
        return <DashboardHome user={user} business={business} />;
      case 'agenda':
        return <DashboardAgenda />;
      case 'servicos':
        return <DashboardServices />;
      case 'clientes':
        return <DashboardClients />;
      case 'estoque':
        return <DashboardStock />;
      case 'relatorios':
        return <DashboardReports />;
      default:
        return <DashboardHome user={user} business={business} />;
    }
  };

  if (!user) {
    return null;
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <AppHeader
        title={tabLabel}
        subtitle={user.email || ''}
        actions={{
          showAdmin: isAdmin(user.uid),
          showSettings: true,
          showLogout: true,
          onAdmin: () => navigate('/admin'),
          onSettings: () => navigate('/dashboard/settings'),
          onLogout: handleLogout,
        }}
      />

      <main className="max-w-screen-xl mx-auto p-4">
        {renderTabContent()}
      </main>

      <BottomNav type="dashboard" />
    </div>
  );
}
