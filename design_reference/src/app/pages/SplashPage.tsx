import { useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { Scissors, Loader2 } from 'lucide-react';
import { getCurrentUser } from '../lib/auth';

export default function SplashPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  useEffect(() => {
    const timer = setTimeout(() => {
      // Check if URL has ?slug=xxx
      const slug = searchParams.get('slug');
      if (slug) {
        navigate(`/b/${slug}`);
        return;
      }

      // Check if user is logged in
      const user = getCurrentUser();
      if (user) {
        navigate('/dashboard');
        return;
      }

      // Default to login
      navigate('/login');
    }, 800);

    return () => clearTimeout(timer);
  }, [navigate, searchParams]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-600 via-pink-500 to-purple-700 flex flex-col items-center justify-center p-4">
      <div className="text-center space-y-6">
        <div className="inline-flex items-center justify-center w-24 h-24 bg-white/20 backdrop-blur-sm rounded-full">
          <Scissors className="w-12 h-12 text-white" />
        </div>
        <h1 className="text-4xl md:text-5xl font-bold text-white">
          Meu Negócio
        </h1>
        <div className="flex justify-center">
          <Loader2 className="w-8 h-8 text-white animate-spin" />
        </div>
      </div>
    </div>
  );
}
