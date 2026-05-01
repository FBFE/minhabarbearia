import { TrendingUp, DollarSign, Users, Calendar } from 'lucide-react';
import { Card } from '../ui/card';

export function DashboardReports() {
  const stats = [
    { label: 'Receita do mês', value: 'R$ 12.450,00', icon: DollarSign, color: 'text-green-600', bgColor: 'bg-green-100' },
    { label: 'Total de atendimentos', value: '156', icon: Users, color: 'text-blue-600', bgColor: 'bg-blue-100' },
    { label: 'Ticket médio', value: 'R$ 79,80', icon: TrendingUp, color: 'text-purple-600', bgColor: 'bg-purple-100' },
    { label: 'Agendamentos', value: '89', icon: Calendar, color: 'text-orange-600', bgColor: 'bg-orange-100' },
  ];

  const revenueByService = [
    { service: 'Corte + Barba', revenue: 5400, percentage: 43 },
    { service: 'Corte Masculino', revenue: 3200, percentage: 26 },
    { service: 'Barba', revenue: 2500, percentage: 20 },
    { service: 'Outros', revenue: 1350, percentage: 11 },
  ];

  return (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">Relatórios e DRE</h2>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <Card key={stat.label} className="p-4">
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-sm text-gray-600 mb-1">{stat.label}</p>
                  <p className="text-2xl font-bold">{stat.value}</p>
                </div>
                <div className={`w-10 h-10 ${stat.bgColor} rounded-lg flex items-center justify-center`}>
                  <Icon className={`w-5 h-5 ${stat.color}`} />
                </div>
              </div>
            </Card>
          );
        })}
      </div>

      <Card className="p-6">
        <h3 className="text-lg font-semibold mb-4">Receita por serviço</h3>
        <div className="space-y-4">
          {revenueByService.map((item) => (
            <div key={item.service}>
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium">{item.service}</span>
                <span className="text-sm text-gray-600">
                  R$ {item.revenue.toLocaleString('pt-BR')} ({item.percentage}%)
                </span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div
                  className="bg-purple-600 h-2 rounded-full"
                  style={{ width: `${item.percentage}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card className="p-6">
          <h3 className="text-lg font-semibold mb-4">Receitas</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Serviços</span>
              <span className="font-semibold">R$ 12.450,00</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Produtos</span>
              <span className="font-semibold">R$ 850,00</span>
            </div>
            <div className="border-t pt-2 flex justify-between font-semibold">
              <span>Total</span>
              <span className="text-green-600">R$ 13.300,00</span>
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <h3 className="text-lg font-semibold mb-4">Despesas</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Produtos</span>
              <span className="font-semibold">R$ 1.200,00</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Aluguel</span>
              <span className="font-semibold">R$ 2.500,00</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-600">Outras</span>
              <span className="font-semibold">R$ 800,00</span>
            </div>
            <div className="border-t pt-2 flex justify-between font-semibold">
              <span>Total</span>
              <span className="text-red-600">R$ 4.500,00</span>
            </div>
          </div>
        </Card>
      </div>

      <Card className="p-6 bg-gradient-to-r from-purple-50 to-pink-50">
        <div className="text-center">
          <p className="text-sm text-gray-600 mb-1">Lucro líquido do mês</p>
          <p className="text-4xl font-bold text-purple-600">R$ 8.800,00</p>
          <p className="text-sm text-green-600 mt-2">+15% vs mês anterior</p>
        </div>
      </Card>
    </div>
  );
}
