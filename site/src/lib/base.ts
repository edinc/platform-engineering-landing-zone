/**
 * Prefix an app-internal path with the configured base path so links work both
 * in local preview and under the GitHub Pages project subpath. Pass-through for
 * hashes, absolute URLs and mailto links.
 */
const BASE_URL: string = import.meta.env.BASE_URL;

export function withBase(path = ""): string {
  const base = BASE_URL.endsWith("/") ? BASE_URL.slice(0, -1) : BASE_URL;
  if (!path) return base || "/";
  if (path.startsWith("#")) return path;
  if (/^(https?:)?\/\//.test(path) || path.startsWith("mailto:")) return path;
  const p = path.startsWith("/") ? path : `/${path}`;
  return `${base}${p}` || "/";
}

/** Canonical repository + docs links reused across the site. */
export const REPO = "https://github.com/edinc/platform-engineering-landing-zone";
export const REPO_BLOB = `${REPO}/blob/main`;
export const REPO_TREE = `${REPO}/tree/main`;

/** Link to a path inside the repository on the default branch. */
export function repoPath(path: string): string {
  const clean = path.replace(/^\/+/, "");
  // crude file-vs-dir heuristic: a trailing slash or no dot in the last segment → tree
  const last = clean.split("/").pop() ?? "";
  const isDir = clean.endsWith("/") || !last.includes(".");
  return `${isDir ? REPO_TREE : REPO_BLOB}/${clean.replace(/\/$/, "")}`;
}
