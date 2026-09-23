# To build: docker build -f Dockerfile -t laudspeaker:local .
# To run: docker run -it -p 80:80 --env-file packages/server/.env --rm laudspeaker:local
FROM node:20 as frontend_build
ARG EXTERNAL_URL
ARG FRONTEND_SENTRY_DSN_URL=https://2444369e8e13b39377ba90663ae552d1@o4506038702964736.ingest.sentry.io/4506038705192960
ENV NODE_OPTIONS=--max-old-space-size=4096
ENV REACT_APP_SENTRY_DSN_URL_FRONTEND=${FRONTEND_SENTRY_DSN_URL}
ENV REACT_APP_WS_BASE_URL=${EXTERNAL_URL}
WORKDIR /app
COPY ./packages/client/package.json /app/
COPY ./package-lock.json /app/
RUN npm install --legacy-peer-deps
COPY . /app
RUN npm run format:client
RUN npm run build:client
RUN echo "Skipping authenticated frontend sourcemap upload"

FROM node:20 as backend_build
WORKDIR /app
COPY ./package.json ./package-lock.json /app/
COPY ./packages/client/package.json /app/packages/client/package.json
COPY ./packages/server/package.json /app/packages/server/package.json
COPY ./packages/tests/package.json /app/packages/tests/package.json
RUN npm ci --legacy-peer-deps
COPY . /app
RUN npm run build:server
RUN echo "Skipping authenticated backend sourcemap upload"
RUN ./node_modules/.bin/sentry-cli releases propose-version > /app/SENTRY_RELEASE

FROM node:20 As final
# Env vars
ARG EXTERNAL_URL
ARG BACKEND_SENTRY_DSN_URL=https://15c7f142467b67973258e7cfaf814500@o4506038702964736.ingest.sentry.io/4506040630640640
ENV SENTRY_DSN_URL_BACKEND=${BACKEND_SENTRY_DSN_URL}
ENV NODE_ENV=production
ENV ENVIRONMENT=production
ENV SERVE_CLIENT_FROM_NEST=true
ENV CLIENT_PATH=/app/client
ENV PATH /app/node_modules/.bin:$PATH
ENV FRONTEND_URL=${EXTERNAL_URL}
ENV POSTHOG_HOST=https://app.posthog.com
ENV NODE_OPTIONS=--max-old-space-size=2560
# Setting working directory
WORKDIR /app

#Copy package.json from server over
COPY ./packages/server/package.json /app

#Copy over all app files
COPY --from=frontend_build /app/packages/client/build /app/client
COPY --from=backend_build /app/packages/server/dist /app/dist
COPY --from=backend_build /app/node_modules /app/node_modules
COPY --from=backend_build /app/packages /app/packages
COPY --from=backend_build /app/SENTRY_RELEASE /app/
COPY ./scripts /app/scripts/

#Expose web port
EXPOSE 80

COPY docker-entrypoint.sh /app/docker-entrypoint.sh

RUN ["chmod", "+x", "/app/docker-entrypoint.sh"]

ENTRYPOINT ["/app/docker-entrypoint.sh"]
