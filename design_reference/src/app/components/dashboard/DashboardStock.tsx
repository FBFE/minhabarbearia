import { Package, TrendingUp, TrendingDown, Plus } from 'lucide-react';
import { Card } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';

interface StockItem {
  id: string;
  name: string;
  quantity: number;
  minQuantity: number;
  unit: string;
  lastMovement: string;
}

export function DashboardStock() {
  const stockItems: StockItem[] = [
    { id: '1', name: 'Pomada modeladora', quantity: 15, minQuantity: 10, unit: 'un', lastMovement: '10/03/2026' },
    { id: '2', name: 'Shampoo', quantity: 8, minQuantity: 5, unit: 'un', lastMovement: '12/03/2026' },
    { id: '3', name: 'Óleo para barba', quantity: 3, minQuantity: 5, unit: 'un', lastMovement: '08/03/2026' },
    { id: '4', name: 'Cera', quantity: 20, minQuantity: 10, unit: 'un', lastMovement: '14/03/2026' },
  ];

  const movements = [
    { id: '1', type: 'entrada', product: 'Pomada modeladora', quantity: 10, date: '10/03/2026' },
    { id: '2', type: 'saida', product: 'Shampoo', quantity: 2, date: '12/03/2026' },
    { id: '3', type: 'saida', product: 'Óleo para barba', quantity: 1, date: '13/03/2026' },
  ];

  const isLowStock = (item: StockItem) => item.quantity <= item.minQuantity;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">Estoque</h2>
        <Button>
          <Plus className="w-4 h-4 mr-2" />
          Adicionar produto
        </Button>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {stockItems.map((item) => (
          <Card key={item.id} className="p-4">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-start gap-3 flex-1">
                <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center flex-shrink-0">
                  <Package className="w-5 h-5 text-purple-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold truncate">{item.name}</h3>
                  <p className="text-xs text-gray-600">Última movimentação: {item.lastMovement}</p>
                </div>
              </div>
              {isLowStock(item) && (
                <Badge variant="destructive" className="text-xs">
                  Baixo
                </Badge>
              )}
            </div>

            <div className="flex items-center justify-between">
              <div>
                <div className="text-2xl font-bold text-purple-600">
                  {item.quantity} <span className="text-sm font-normal text-gray-600">{item.unit}</span>
                </div>
                <div className="text-xs text-gray-600">Mínimo: {item.minQuantity} {item.unit}</div>
              </div>
              <div className="flex gap-1">
                <Button size="sm" variant="outline">
                  <TrendingUp className="w-4 h-4" />
                </Button>
                <Button size="sm" variant="outline">
                  <TrendingDown className="w-4 h-4" />
                </Button>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <div>
        <h3 className="text-lg font-semibold mb-3">Últimas movimentações</h3>
        <div className="space-y-2">
          {movements.map((movement) => (
            <Card key={movement.id} className="p-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  {movement.type === 'entrada' ? (
                    <div className="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                      <TrendingUp className="w-4 h-4 text-green-600" />
                    </div>
                  ) : (
                    <div className="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center">
                      <TrendingDown className="w-4 h-4 text-red-600" />
                    </div>
                  )}
                  <div>
                    <div className="font-medium text-sm">{movement.product}</div>
                    <div className="text-xs text-gray-600">
                      {movement.type === 'entrada' ? 'Entrada' : 'Saída'} de {movement.quantity} un
                    </div>
                  </div>
                </div>
                <div className="text-xs text-gray-600">{movement.date}</div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
