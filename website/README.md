# Loudkeeper website

This is the standalone product website for Loudkeeper. It is plain HTML, CSS, and JavaScript, with no build step or application backend. The pages cover the product and three example use cases: onboarding, activation, and retention.

Preview locally:

```sh
python3 -m http.server 4173 --directory website
```

Then open `http://localhost:4173`. The existing product application lives in `packages/client/` and is separate from this site.

## Cloudflare Workers

The [`wrangler.jsonc`](wrangler.jsonc) in this directory deploys the site as static assets, with no server-side Worker code. In **Workers & Pages**, connect a **Worker** to `helpin-labs/loudkeeper` and select `main` for production. Set **Root directory** to `website`, leave **Build command** blank, and set **Deploy command** to `npx wrangler deploy`. Name the Worker `loudkeeper-website` to match the Wrangler configuration. This isolates the static site from the repository root's npm workspaces and lockfile. Cloudflare will publish the site when `main` is pushed.

After the first deployment, add `useloudkeeper.com` as a custom domain on the Worker. Add `www.useloudkeeper.com` too if you want that hostname. The site has no Helpin pixel yet; add the project's exact Helpin snippet after the first publication.
