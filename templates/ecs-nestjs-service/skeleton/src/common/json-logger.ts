import { LoggerService } from '@nestjs/common';

const INFO = {
  service: process.env.SERVICE_NAME ?? '${{ values.name }}',
  environment: process.env.ENVIRONMENT ?? 'local',
  version: process.env.APP_VERSION ?? 'dev',
};

/** One JSON object per line on stdout (CloudWatch Logs friendly). */
export class JsonLogger implements LoggerService {
  private write(level: string, message: unknown, context?: string, extra: object = {}) {
    process.stdout.write(
      JSON.stringify({ time: new Date().toISOString(), level, msg: message, context, ...INFO, ...extra }) + '\n',
    );
  }
  log(message: unknown, context?: string) { this.write('info', message, context); }
  error(message: unknown, trace?: string, context?: string) { this.write('error', message, context, { trace }); }
  warn(message: unknown, context?: string) { this.write('warn', message, context); }
  debug(message: unknown, context?: string) { this.write('debug', message, context); }
  verbose(message: unknown, context?: string) { this.write('verbose', message, context); }
  request(fields: object) { this.write('info', 'request', 'HTTP', fields); }
}

export const logger = new JsonLogger();
export { INFO };
