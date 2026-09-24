import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createApp } from '../src/main';

// End-to-end: the real app against a real PostgreSQL (CI starts one; locally: docker run postgres).
describe('${{ values.name }} (e2e)', () => {
  let app: INestApplication;
  const base = '/api';

  beforeAll(async () => {
    process.env.BASE_PATH = base;
    app = await createApp();
    await app.init(); // runs migrations
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health is ok', () =>
    request(app.getHttpServer()).get(`${base}/health`).expect(200).expect({ status: 'ok' }));

  it('GET /ready reaches the database', () =>
    request(app.getHttpServer()).get(`${base}/ready`).expect(200));

  it('creates a product and orders it (module boundary via service)', async () => {
    const product = await request(app.getHttpServer())
      .post(`${base}/products`)
      .send({ name: 'Green tea', priceCents: 450 })
      .expect(201);
    const order = await request(app.getHttpServer())
      .post(`${base}/orders`)
      .send({ productId: product.body.id, quantity: 2 })
      .expect(201);
    expect(order.body.totalCents).toBe(900);
  });

  it('rejects an order for an unknown product', () =>
    request(app.getHttpServer())
      .post(`${base}/orders`)
      .send({ productId: '00000000-0000-4000-8000-000000000000', quantity: 1 })
      .expect(404));
});
