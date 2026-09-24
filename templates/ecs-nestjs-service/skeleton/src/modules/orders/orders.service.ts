import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ProductsService } from '../products/products.service';
import { Order } from './order.entity';

@Injectable()
export class OrdersService {
  constructor(
    @InjectRepository(Order) private readonly orders: Repository<Order>,
    private readonly products: ProductsService, // module boundary: service, never the products table
  ) {}

  async place(productId: string, quantity: number): Promise<Order> {
    if (!Number.isInteger(quantity) || quantity < 1) throw new BadRequestException('quantity must be >= 1');
    const product = await this.products.get(productId); // 404 if unknown
    return this.orders.save(
      this.orders.create({ productId, quantity, totalCents: product.priceCents * quantity }),
    );
  }

  list(): Promise<Order[]> {
    return this.orders.find({ order: { createdAt: 'DESC' }, take: 100 });
  }
}
