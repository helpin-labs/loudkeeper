# Loudkeeper staging

Argo CD deploys this Kustomization from the `staging` branch into the
`loudkeeper` namespace. The release workflow updates `images[0].newTag` to the
exact RC image after publishing it.

Images in `ghcr.io/helpin-labs/loudkeeper` are public, so the deployment does
not use an image pull secret. The namespace must contain a `loudkeeper-secrets`
secret with the runtime configuration for PostgreSQL, MongoDB, Redis, RabbitMQ,
ClickHouse, object storage, and authentication. At a minimum, configure the
variables documented in `env-server-example` and `local-env/env-docker-compose`,
including:

- `DATABASE_HOST`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`, and
  `DATABASE_PORT`
- `MONGOOSE_URL` and `MONGO_DB_NAME`
- `REDIS_HOST`, `REDIS_PORT`, and `REDIS_PASSWORD`
- `RMQ_CONNECTION_URI`
- `CLICKHOUSE_HOST`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, and the
  `CH_MIGRATIONS_*` variables
- `JWT_KEY` and `JWT_EXPIRES`
- `MINIO_S3_URL`, `AWS_S3_BUCKET`, `AWS_S3_CUSTOMERS_IMPORT_BUCKET`,
  `AWS_S3_ACCESS_KEY`, and `AWS_S3_KEY_SECRET`

The public staging endpoint is `https://app.loudkeeper.ai`. Its DNS record must
point at the staging ingress. Cert-manager provisions the namespace-local TLS
secret through the `letsencrypt-prod` ClusterIssuer.
