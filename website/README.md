# Loudkeeper website

This is the standalone product website for Loudkeeper. It is plain HTML, CSS, and JavaScript, with no build step or application backend. A small Cloudflare Worker adds the Helpin pixel to HTML responses. Its small npm project pins Wrangler for deployment. The pages cover the product and three example use cases: onboarding, activation, and retention.

Preview locally:

```sh
python3 -m http.server 4173 --directory website
```

Then open `http://localhost:4173`. The existing product application lives in `packages/client/` and is separate from this site.

## Cloudflare Workers

The [`wrangler.jsonc`](wrangler.jsonc) in this directory deploys the site as static assets and runs [`worker.js`](worker.js) before serving them. The Worker adds the Helpin pixel to HTML pages using the public widget key in Wrangler's `vars`. In **Workers & Pages**, connect a **Worker** to `helpin-labs/loudkeeper` and select `main` for production. Set **Root directory** to `website`, leave **Build command** blank, and set **Deploy command** to `npx wrangler deploy`. Name the Worker `loudkeeper-website` to match the Wrangler configuration. The site-local package and lockfile let Cloudflare install Wrangler without using the repository root's npm workspaces and lockfile. Cloudflare will publish the site when `main` is pushed.

The `useloudkeeper.com` custom domain is declared in `wrangler.jsonc` so deployments retain it. Add `www.useloudkeeper.com` to the routes too if you want that hostname.

The Helpin widget key is public because the browser receives it in the pixel script. Keep it in `wrangler.jsonc` so `wrangler deploy` retains it. The `.assetsignore` file prevents Worker code, configuration, and npm files from being published as website assets.
