import json
import os
import ssl
import sys
import urllib.error
import urllib.request

BACKSTAGE_BASE_URL = os.environ["BACKSTAGE_BASE_URL"].rstrip("/")
GITHUB_ORG = os.environ["GITHUB_ORG"]
BACKSTAGE_SERVICE_TOKEN = os.environ.get("BACKSTAGE_SERVICE_TOKEN")
if not BACKSTAGE_SERVICE_TOKEN and os.environ.get("BACKSTAGE_SERVICE_TOKEN_FILE"):
    with open(os.environ["BACKSTAGE_SERVICE_TOKEN_FILE"], encoding="utf-8") as token_file:
        BACKSTAGE_SERVICE_TOKEN = token_file.read().strip()
if not BACKSTAGE_SERVICE_TOKEN:
    raise RuntimeError("BACKSTAGE_SERVICE_TOKEN or BACKSTAGE_SERVICE_TOKEN_FILE is required")
RAW_GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
GITHUB_TOKEN = None if RAW_GITHUB_TOKEN.lower().startswith("placeholder") else RAW_GITHUB_TOKEN
TEAMS_WEBHOOK_URL = os.environ.get("TEAMS_WEBHOOK_URL", "")
NAMESPACE_LABEL = "platform.example.io/team"
OWNER_PREFIX = "group:default/"


def request_json_response(url, token=None, cafile=None):
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, context=ssl.create_default_context(cafile=cafile), timeout=20) as response:
        return json.loads(response.read().decode("utf-8")), response.headers


def request_json(url, token=None, cafile=None):
    body, _ = request_json_response(url, token, cafile)
    return body


def next_link(headers):
    for value in headers.get_all("Link", []):
        for part in value.split(","):
            section = part.strip().split(";")
            if len(section) == 2 and section[1].strip() == 'rel="next"':
                return section[0].strip()[1:-1]
    return None


def catalog_components():
    response = request_json(
        f"{BACKSTAGE_BASE_URL}/api/catalog/entities?filter=kind=component",
        BACKSTAGE_SERVICE_TOKEN,
    )
    repos = set()
    namespaces_by_owner = {}
    for entity in response:
        spec = entity.get("spec", {})
        annotations = entity.get("metadata", {}).get("annotations", {})
        managed_by = annotations.get("backstage.io/managed-by-origin-location") or annotations.get("backstage.io/managed-by-location", "")
        if managed_by.startswith(f"url:https://github.com/{GITHUB_ORG}/"):
            repo_path = managed_by.split("/blob/", 1)[0].split("/tree/", 1)[0].rstrip("/").rsplit("/", 1)
            if len(repo_path) == 2:
                repos.add(repo_path[1])
        kubernetes_id = annotations.get("backstage.io/kubernetes-id")
        owner = spec.get("owner", "")
        if kubernetes_id and owner.startswith(OWNER_PREFIX):
            namespaces_by_owner[kubernetes_id] = owner.removeprefix(OWNER_PREFIX)
    return repos, namespaces_by_owner


def github_catalog_repos():
    if not GITHUB_TOKEN:
        print(
            json.dumps(
                {
                    "event": "github-token-disabled",
                    "reason": "placeholder-or-empty-token",
                },
                sort_keys=True,
            ),
            file=sys.stderr,
        )
    org_repos_url = f"https://api.github.com/orgs/{GITHUB_ORG}/repos?per_page=100"
    user_repos_url = f"https://api.github.com/users/{GITHUB_ORG}/repos?per_page=100"
    url = org_repos_url
    repos = []
    while url:
        try:
            page, headers = request_json_response(url, GITHUB_TOKEN)
        except urllib.error.HTTPError as error:
            if error.code == 404 and url == org_repos_url:
                url = user_repos_url
                continue
            raise
        repos.extend(page)
        url = next_link(headers)
    discovered = set()
    for repo in repos:
        contents_url = repo["contents_url"].replace("{+path}", "catalog-info.yaml")
        try:
            request_json(contents_url, GITHUB_TOKEN)
            discovered.add(repo["name"])
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise
    return discovered


def namespaces():
    token = open("/var/run/secrets/kubernetes.io/serviceaccount/token", encoding="utf-8").read()
    response = request_json(
        "https://kubernetes.default.svc/api/v1/namespaces",
        token,
        "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
    )
    return {
        item["metadata"]["name"]: item["metadata"].get("labels", {}).get(NAMESPACE_LABEL)
        for item in response["items"]
        if NAMESPACE_LABEL in item["metadata"].get("labels", {})
    }


def report_to_teams(drift):
    if not TEAMS_WEBHOOK_URL:
        return
    missing = drift["missingReposFromCatalog"] + drift["missingNamespacesFromCatalog"]
    if not missing:
        return
    payload = {
        "text": "platform-drift detected: " + ", ".join(missing),
    }
    request = urllib.request.Request(
        TEAMS_WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, context=ssl.create_default_context(), timeout=20):
        return


def main():
    catalog_repos, catalog_namespaces_by_owner = catalog_components()
    vended_namespaces = namespaces()
    drift = {
        "catalogRepos": sorted(catalog_repos),
        "catalogKubernetesIds": sorted(catalog_namespaces_by_owner.keys()),
        "githubCatalogRepos": sorted(github_catalog_repos()),
        "vendedNamespaces": sorted(vended_namespaces.keys()),
    }
    drift["missingReposFromCatalog"] = sorted(set(drift["githubCatalogRepos"]) - catalog_repos)
    drift["missingNamespacesFromCatalog"] = sorted(
        namespace
        for namespace, team in vended_namespaces.items()
        if catalog_namespaces_by_owner.get(namespace) != team
    )
    print(json.dumps({"event": "platform-drift", **drift}, sort_keys=True))
    if drift["missingReposFromCatalog"] or drift["missingNamespacesFromCatalog"]:
      report_to_teams(drift)
      return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
