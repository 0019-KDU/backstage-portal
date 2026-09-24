import { Body, Controller, Get, Post } from '@nestjs/common';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Post()
  place(@Body() body: { productId: string; quantity: number }) {
    return this.orders.place(body.productId, body.quantity);
  }

  @Get()
  list() {
    return this.orders.list();
  }
}
