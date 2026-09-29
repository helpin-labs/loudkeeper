import { MigrationInterface, QueryRunner } from 'typeorm';
import { ClickHouseClient } from '@/common/services/clickhouse';

export class CreateClickhouseMessageStatusPGSyncMV1736737126920
  implements MigrationInterface
{
  public async up(queryRunner: QueryRunner): Promise<void> {
    const clickhouseClient = new ClickHouseClient({
      url: process.env.CLICKHOUSE_HOST
        ? process.env.CLICKHOUSE_HOST.includes('http')
          ? process.env.CLICKHOUSE_HOST
          : `http://${process.env.CLICKHOUSE_HOST}`
        : 'http://localhost:8123',
      username: process.env.CLICKHOUSE_USER ?? 'default',
      password: process.env.CLICKHOUSE_PASSWORD ?? '',
      database: process.env.CLICKHOUSE_DB ?? 'default',
      max_open_connections: parseInt(
        process.env.CLICKHOUSE_MAX_OPEN_CONNECTIONS ?? '10'
      ),
      keep_alive: { enabled: true },
    });

    await clickhouseClient.query({
      query: `
          DROP TABLE IF EXISTS message_status_sync_trigger;
        `,
    });
    await clickhouseClient.query({
      query: `
          CREATE TABLE IF NOT EXISTS message_status_pg_sync_v2 (
            pg_sync_published_at DateTime64(6) NOT NULL,
            created_at DateTime64(6) NOT NULL DEFAULT now64(),
            stepId UUID NOT NULL,
            customerId String NOT NULL,
            templateId String NOT NULL,
            messageId String NOT NULL,
            event String NOT NULL,
            eventProvider String NOT NULL,
            createdAt DateTime64(6) NOT NULL,
            processed Boolean NOT NULL,
            userId UUID NOT NULL,
            workspaceId String NOT NULL
          ) ENGINE = RabbitMQ SETTINGS
            rabbitmq_host_port = 'rabbitmq:5672',
            rabbitmq_exchange_name = '',
            rabbitmq_format = 'JSONEachRow',
            rabbitmq_persistent = 1,
            rabbitmq_queue_consume = 1,
            rabbitmq_max_rows_per_message = 100,
            rabbitmq_routing_key_list = 'message_status_pg_sync.pending',
            rabbitmq_queue_base = 'message_status_pg_sync.pending';
        `,
    });
    await clickhouseClient.query({
      query: `
          CREATE MATERIALIZED VIEW message_status_sync_trigger TO message_status_pg_sync_v2
          AS SELECT
            now64() as pg_sync_published_at,
            now64() as created_at,
            stepId,
            customerId,
            templateId,
            messageId,
            event,
            eventProvider,
            createdAt,
            processed,
            toUUID('00000000-0000-0000-0000-000000000000') as userId,
            workspaceId
          FROM message_status;
        `,
    });
  }

  public async down(queryRunner: QueryRunner): Promise<void> {}
}
