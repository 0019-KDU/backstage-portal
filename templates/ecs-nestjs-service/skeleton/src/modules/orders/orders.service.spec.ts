import { BadRequestException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { ProductsService } from '../products/products.service';
import { Order } from './order.entity';
import { OrdersService } from './orders.service';

// Unit test: no database; the products module is replaced by a fake of its public API.
describe('OrdersService', () => {
  const repo = {
    create: jest.fn((o: Partial<Order>) => o),
    save: jest.fn(async (o: Partial<Order>) => ({ id: 'o-1', ...o })),
  } as unknown as Repository<Order>;
  const products = { get: jest.fn(async () => ({ id: 'p-1', name: 'Tea', priceCents: 250 })) } as unknown as ProductsService;
  const service = new OrdersService(repo, products);

  it('computes the total from the product price', async () => {
    const order = await service.place('p-1', 3);
    expect(order.totalCents).toBe(750);
    expect(products.get).toHaveBeenCalledWith('p-1');
  });

  it('rejects a zero quantity', async () => {
    await expect(service.place('p-1', 0)).rejects.toBeInstanceOf(BadRequestException);
  });
});
