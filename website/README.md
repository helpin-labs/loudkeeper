# Loudkeeper website

This is the standalone product website for Loudkeeper. It is plain HTML, CSS, and JavaScript, with no build step or application backend. The pages cover the product and three example use cases: onboarding, activation, and retention.

Preview locally:

```sh
python3 -m http.server 4173 --directory website
```

Then open `http://localhost:4173`. The existing product application lives in `packages/client/` and is separate from this site.

## Cloudflare Pages

The website is deployed from [`deploy-website.yml`](../.github/workflows/deploy-website.yml). It publishes `website/` when a GitHub release is published. Its manual `workflow_dispatch` trigger can publish the site for the first time after this workflow is merged into the repository's default branch. On a release, the workflow checks out the release tag, so the deployed files match that release.

One-time setup:

1. Create a **Direct Upload** Cloudflare Pages project named `loudkeeper-website` with production branch `release`. Keep it in the same Cloudflare account as the `useloudkeeper.com` zone.
2. Create a Cloudflare API token with **Account → Cloudflare Pages → Edit** permission, scoped to that account. Add it to the GitHub repository as `CLOUDFLARE_API_TOKEN`; add the account ID as `CLOUDFLARE_ACCOUNT_ID`.
3. Run **Publish Loudkeeper website** from the GitHub Actions tab once for the initial deployment. The project will first be available at `loudkeeper-website.pages.dev`.
4. In **Workers & Pages → loudkeeper-website → Custom domains**, add `useloudkeeper.com`. Cloudflare will create or guide you through the required DNS records and certificate setup. Add `www.useloudkeeper.com` there too if you want the `www` hostname to work.

After setup, publish a GitHub release to deploy that release's website automatically. The site has no Helpin pixel yet; add the project's exact Helpin snippet after the first publication.
