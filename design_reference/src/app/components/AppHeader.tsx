import { ArrowLeft, Settings, LogOut, Shield } from 'lucide-react';
import { useNavigate } from 'react-router';
import { Button } from './ui/button';

interface AppHeaderProps {
  title: string;
  subtitle?: string;
  showBack?: boolean;
  onBack?: () => void;
  actions?: {
    showSettings?: boolean;
    showLogout?: boolean;
    showAdmin?: boolean;
    onSettings?: () => void;
    onLogout?: () => void;
    onAdmin?: () => void;
  };
  backgroundColor?: string;
  textColor?: string;
}

export function AppHeader({
  title,
  subtitle,
  showBack = false,
  onBack,
  actions,
  backgroundColor = 'bg-white',
  textColor = 'text-gray-900',
}: AppHeaderProps) {
  const navigate = useNavigate();

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      navigate(-1);
    }
  };

  return (
    <header className={`sticky top-0 z-40 ${backgroundColor} border-b border-gray-200`}>
      <div className="flex items-center justify-between h-14 px-4 max-w-screen-xl mx-auto">
        <div className="flex items-center gap-3 flex-1 min-w-0">
          {showBack && (
            <Button
              variant="ghost"
              size="icon"
              onClick={handleBack}
              className="flex-shrink-0"
            >
              <ArrowLeft className="w-5 h-5" />
            </Button>
          )}
          <div className="min-w-0 flex-1">
            <h1 className={`text-lg font-semibold truncate ${textColor}`}>
              {title}
            </h1>
            {subtitle && (
              <p className={`text-xs ${textColor} opacity-70 truncate`}>
                {subtitle}
              </p>
            )}
          </div>
        </div>

        {actions && (
          <div className="flex items-center gap-1 flex-shrink-0">
            {actions.showAdmin && actions.onAdmin && (
              <Button variant="ghost" size="icon" onClick={actions.onAdmin}>
                <Shield className="w-5 h-5" />
              </Button>
            )}
            {actions.showSettings && actions.onSettings && (
              <Button variant="ghost" size="icon" onClick={actions.onSettings}>
                <Settings className="w-5 h-5" />
              </Button>
            )}
            {actions.showLogout && actions.onLogout && (
              <Button variant="ghost" size="icon" onClick={actions.onLogout}>
                <LogOut className="w-5 h-5" />
              </Button>
            )}
          </div>
        )}
      </div>
    </header>
  );
}
