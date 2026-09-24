import { MigrationInterface, QueryRunner } from 'typeorm';

/** Initial schema. One table group per module; modules never read each other's tables. */
export class Init1790000000000 implements MigrationInterface {
  name = 'Init1790000000000';

  async up(q: QueryRunner): Promise<void> {
    await q.query(`CREATE TABLE products (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name varchar(200) NOT NULL,
      price_cents integer NOT NULL CHECK (price_cents >= 0),
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await q.query(`CREATE TABLE orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      product_id uuid NOT NULL,
      quantity integer NOT NULL CHECK (quantity > 0),
      total_cents integer NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
  }

  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE orders');
    await q.query('DROP TABLE products');
  }
}
