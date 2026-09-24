import { BadRequestException, Body, Controller, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ProductsService } from './products.service';

@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  @Post()
  create(@Body() body: { name?: unknown; priceCents?: unknown }) {
    if (typeof body.name !== 'string' || !body.name.trim()) throw new BadRequestException('name is required');
    if (!Number.isInteger(body.priceCents) || (body.priceCents as number) < 0)
      throw new BadRequestException('priceCents must be a non-negative integer');
    return this.products.create(body.name.trim(), body.priceCents as number);
  }

  @Get()
  list() {
    return this.products.list();
  }

  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.products.get(id);
  }
}
