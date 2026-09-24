import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { INFO } from '../../common/json-logger';

@Controller()
export class HealthController {
  constructor(private readonly db: DataSource) {}

  /** Liveness for the load balancer: the process is up and serving. */
  @Get('health')
  health() {
    return { status: 'ok' };
  }

  /** Readiness: dependencies (database) reachable. */
  @Get('ready')
  async ready() {
    try {
      await this.db.query('SELECT 1');
      return { status: 'ready', database: 'ok' };
    } catch {
      throw new ServiceUnavailableException({ status: 'not-ready', database: 'unreachable' });
    }
  }

  @Get()
  info() {
    return { ...INFO, message: 'Hello from the DevOps94 IDP', time: new Date().toISOString() };
  }
}
