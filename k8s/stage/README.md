# Loudkeeper staging

Argo CD deploys this Kustomization from the `staging` branch into the
`loudkeeper` namespace. The release workflow updates `images[0].newTag` to the
exact RC image after publishing it.

Images in `ghcr.io/helpin-labs/loudkeeper` are public, so the deployment does
not use an image pull secret.

The Kustomization provisions these app-specific data services:

- A three-instance CloudNativePG PostgreSQL 18 cluster. CNPG generates the
  `loudkeeper-postgres-app` application credential secret.
- A three-node RabbitMQ 4.3 cluster using persistent volumes and quorum queues.
- A single-replica, persistent ClickHouse installation managed by the Altinity
  operator.

All three use the `hcloud-volumes-retain` storage class so an accidental Argo
prune does not delete the underlying data volumes.

The namespace must contain a `loudkeeper-secrets` secret with the remaining
runtime configuration. PostgreSQL connection settings and service addresses
are managed by the manifests. At a minimum, configure the variables documented
in `env-server-example` and `local-env/env-docker-compose`, including:

- `REDIS_HOST`, `REDIS_PORT`, and `REDIS_PASSWORD`
- `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`, and `RABBITMQ_ERLANG_COOKIE`
- `RMQ_CONNECTION_URI`, using the same RabbitMQ username and password and the
  `rabbitmq:5672` service address
- `CLICKHOUSE_PASSWORD`
- `JWT_KEY` and `JWT_EXPIRES`
- `MINIO_S3_URL`, `AWS_S3_BUCKET`, `AWS_S3_CUSTOMERS_IMPORT_BUCKET`,
  `AWS_S3_ACCESS_KEY`, and `AWS_S3_KEY_SECRET`

MongoDB is not required for a new deployment. Its only active reference is an
old MongoDB-to-ClickHouse data migration, which safely skips when MongoDB is not
configured.

RabbitMQ credentials should use URL-safe characters because
`RMQ_CONNECTION_URI` is an AMQP URI. The three RabbitMQ pods require three
different Kubernetes worker nodes because hard pod anti-affinity protects the
quorum during a node failure.

The public staging endpoint is `https://app.loudkeeper.ai`. Its DNS record must
point at the staging ingress. Cert-manager provisions the namespace-local TLS
secret through the `letsencrypt-prod` ClusterIssuer.
