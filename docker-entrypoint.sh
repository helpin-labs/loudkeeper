#!/bin/bash
set -e

# The web process owns schema migrations. Queue and cron processes can start in
# parallel without racing the same migration tables.
if [[ "$1" = 'web' || -z "$1" ]]; then
	export LAUDSPEAKER_PROCESS_TYPE=WEB

	if [[ "${RUN_MIGRATIONS:-true}" = 'true' ]]; then
		echo "Running clickhouse-migrations"
		clickhouse-migrations migrate

		echo "Running Typeorm migrations"
		typeorm migration:run -d dist/src/data-source.js
	fi

	echo "Running setup_config.sh"
	bash ./scripts/setup_config.sh
fi

if [[ "$1" = 'queue' ]]; then
	export LAUDSPEAKER_PROCESS_TYPE=QUEUE
	unset SERVE_CLIENT_FROM_NEST
fi

if [[ "$1" = 'cron' ]]; then
	export LAUDSPEAKER_PROCESS_TYPE=CRON
	unset SERVE_CLIENT_FROM_NEST
fi

export SENTRY_RELEASE=$(cat SENTRY_RELEASE)

echo "Starting LaudSpeaker Process: $LAUDSPEAKER_PROCESS_TYPE"
node dist/src/main.js
