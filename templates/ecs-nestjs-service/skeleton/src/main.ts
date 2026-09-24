import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { logger } from './common/json-logger';

export async function createApp() {
  const app = await NestFactory.create(AppModule, { logger });
  // The environment's load balancer routes /<service>/* here: serve everything under it
  const basePath = (process.env.BASE_PATH ?? '').replace(/^\/+|\/+$/g, '');
  if (basePath) app.setGlobalPrefix(basePath);
  app.enableShutdownHooks(); // ECS sends SIGTERM: finish requests, close DB pool
  return app;
}

async function bootstrap() {
  const app = await createApp();
  const port = Number(process.env.PORT ?? 8080);
  await app.listen(port, '0.0.0.0');
  logger.log(`listening on ${port}`, 'Bootstrap');
}

if (require.main === module) {
  void bootstrap();
}
