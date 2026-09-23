# Loudkeeper website

This is the standalone product website for Loudkeeper. It is plain HTML, CSS, and JavaScript, with no build step or application backend. The pages cover the product and three example use cases: onboarding, activation, and retention.

Preview locally:

```sh
python3 -m http.server 4173 --directory website
```

Then open `http://localhost:4173`. Deploy the contents of `website/` to any static host. The existing product application lives in `packages/client/` and is separate from this site.
