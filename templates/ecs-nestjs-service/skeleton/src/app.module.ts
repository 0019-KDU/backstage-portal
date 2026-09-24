import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RequestLoggingMiddleware } from './common/request-logging.middleware';
import { databaseOptions } from './database/database.config';
import { HealthModule } from './modules/health/health.module';
import { OrdersModule } from './modules/orders/orders.module';
import { ProductsModule } from './modules/products/products.module';

/**
 * Modular monolith: one deployable, business capabilities as modules.
 * Add a capability = add a folder under src/modules with its own module,
 * entities and migrations; expose only a service to other modules.
 */
@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      useFactory: () => ({ ...databaseOptions(), autoLoadEntities: true }),
    }),
    HealthModule,
    ProductsModule,
    OrdersModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggingMiddleware).forRoutes('*path');
  }
}
