import { Injectable, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import { logger } from './json-logger';

/** Logs every request except load-balancer health checks. */
@Injectable()
export class RequestLoggingMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const started = process.hrtime.bigint();
    res.on('finish', () => {
      if (req.originalUrl.endsWith('/health')) return;
      logger.request({
        method: req.method,
        path: req.originalUrl,
        status: res.statusCode,
        ms: Number((process.hrtime.bigint() - started) / 1_000_000n),
      });
    });
    next();
  }
}
