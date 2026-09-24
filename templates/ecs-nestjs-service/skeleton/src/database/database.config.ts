import { readFileSync } from 'node:fs';
import { DataSourceOptions } from 'typeorm';

/**
 * Connection settings come from the environment:
 *  - locally / in CI: plain values (docker Postgres)
 *  - on AWS: DB_HOST/DB_PORT/DB_NAME/DB_USER from Terraform, DB_PASSWORD injected by ECS
 *    from Secrets Manager (RDS-managed password), TLS verified with the RDS CA bundle.
 */
export function databaseOptions(): DataSourceOptions {
  const ssl = process.env.DB_SSL === 'true';
  return {
    type: 'postgres',
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    database: process.env.DB_NAME ?? 'app',
    username: process.env.DB_USER ?? 'app',
    password: process.env.DB_PASSWORD ?? 'app',
    ssl: ssl
      ? { ca: readFileSync(process.env.DB_SSL_CA ?? '/app/certs/rds-global-bundle.pem', 'utf8'), rejectUnauthorized: true }
      : false,
    synchronize: false, // schema changes only through migrations
    migrationsRun: true, // apply pending migrations at startup (write them backward-compatible: blue/green runs old + new code together)
    migrations: [__dirname + '/migrations/*{.ts,.js}'],
  };
}
