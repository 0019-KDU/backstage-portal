import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Product } from './product.entity';

/** The ONLY way other modules may use products (public API of this module). */
@Injectable()
export class ProductsService {
  constructor(@InjectRepository(Product) private readonly products: Repository<Product>) {}

  create(name: string, priceCents: number): Promise<Product> {
    return this.products.save(this.products.create({ name, priceCents }));
  }

  list(): Promise<Product[]> {
    return this.products.find({ order: { createdAt: 'DESC' }, take: 100 });
  }

  async get(id: string): Promise<Product> {
    const product = await this.products.findOneBy({ id });
    if (!product) throw new NotFoundException(`product ${id} not found`);
    return product;
  }
}
