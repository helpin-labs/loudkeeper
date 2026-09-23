# Loudkeeper website

This is the standalone product website for Loudkeeper. It is plain HTML, CSS, and JavaScript, with no build step or application backend. The pages cover the product and three example use cases: onboarding, activation, and retention.

Preview locally:

```sh
python3 -m http.server 4173 --directory website
```

Then open `http://localhost:4173`. The existing product application lives in `packages/client/` and is separate from this site.

## Cloudflare Pages

Use Cloudflare Pages Git integration to pull the site directly from GitHub. In **Workers & Pages**, create a **Pages** application, connect `helpin-labs/loudkeeper`, and choose `main` as the production branch. Leave the framework preset and build command blank, keep the repository root as the root directory, and set the build output directory to `website`. Cloudflare will publish the site when `main` is pushed. This repository must have a `main` branch before you can select it in Cloudflare.

After the first deployment, open the Pages project's **Custom domains** settings and add `useloudkeeper.com`. Add `www.useloudkeeper.com` too if you want that hostname. The site has no Helpin pixel yet; add the project's exact Helpin snippet after the first publication.
