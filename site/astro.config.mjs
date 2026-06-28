// @ts-check
import { defineConfig } from "astro/config";
import svelte from "@astrojs/svelte";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";

// Project-pages deployment target. Kept correct from day one so the *built*
// artifact (astro build && astro preview) is validated against the real base
// path locally, before any GitHub Pages deploy is ever enabled (Phase A gate).
const SITE = "https://edinc.github.io";
const BASE = "/platform-engineering-landing-zone";

// https://astro.build/config
export default defineConfig({
  site: SITE,
  base: BASE,
  trailingSlash: "ignore",
  build: { format: "directory" },
  prefetch: { defaultStrategy: "viewport" },
  integrations: [svelte(), mdx(), sitemap()],
  devToolbar: { enabled: false },
});
