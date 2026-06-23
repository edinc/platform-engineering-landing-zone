import importlib
import os
import urllib.error
import unittest
from unittest.mock import patch


class Headers:
    def __init__(self, links=None):
        self._links = links or []

    def get_all(self, name, default=None):
        return self._links if name == "Link" else []


class GitHubCatalogReposTest(unittest.TestCase):
    def setUp(self):
        os.environ["BACKSTAGE_BASE_URL"] = "http://backstage.example"
        os.environ["BACKSTAGE_SERVICE_TOKEN"] = "backstage-token"
        os.environ["GITHUB_ORG"] = "edinc"
        os.environ["GITHUB_TOKEN"] = "github-token"
        self.reconciler = importlib.reload(importlib.import_module("reconciler"))

    def test_falls_back_to_user_repos_when_owner_is_not_an_org(self):
        calls = []

        def request_json_response(url, token=None, cafile=None):
            calls.append(url)
            if url.startswith("https://api.github.com/orgs/"):
                raise urllib.error.HTTPError(url, 404, "Not Found", {}, None)
            return (
                [
                    {
                        "name": "platform-engineering-landing-zone",
                        "contents_url": "https://api.github.com/repos/edinc/platform-engineering-landing-zone/contents/{+path}",
                    }
                ],
                Headers(),
            )

        with (
            patch.object(
                self.reconciler,
                "request_json_response",
                side_effect=request_json_response,
            ),
            patch.object(self.reconciler, "request_json", return_value={}),
        ):
            repos = self.reconciler.github_catalog_repos()

        self.assertEqual(repos, {"platform-engineering-landing-zone"})
        self.assertEqual(
            calls,
            [
                "https://api.github.com/orgs/edinc/repos?per_page=100",
                "https://api.github.com/users/edinc/repos?per_page=100",
            ],
        )

    def test_keeps_org_endpoint_when_it_succeeds(self):
        with (
            patch.object(
                self.reconciler,
                "request_json_response",
                return_value=(
                    [
                        {
                            "name": "platform-engineering-landing-zone",
                            "contents_url": "https://api.github.com/repos/edinc/platform-engineering-landing-zone/contents/{+path}",
                        }
                    ],
                    Headers(),
                ),
            ) as request_json_response,
            patch.object(self.reconciler, "request_json", return_value={}),
        ):
            repos = self.reconciler.github_catalog_repos()

        self.assertEqual(repos, {"platform-engineering-landing-zone"})
        request_json_response.assert_called_once_with(
            "https://api.github.com/orgs/edinc/repos?per_page=100",
            "github-token",
        )

    def test_ignores_placeholder_github_token(self):
        os.environ["GITHUB_TOKEN"] = "placeholder-token-not-for-production"
        reconciler = importlib.reload(importlib.import_module("reconciler"))

        with (
            patch.object(
                reconciler,
                "request_json_response",
                return_value=(
                    [
                        {
                            "name": "platform-engineering-landing-zone",
                            "contents_url": "https://api.github.com/repos/edinc/platform-engineering-landing-zone/contents/{+path}",
                        }
                    ],
                    Headers(),
                ),
            ) as request_json_response,
            patch.object(reconciler, "request_json", return_value={}) as request_json,
        ):
            repos = reconciler.github_catalog_repos()

        self.assertEqual(repos, {"platform-engineering-landing-zone"})
        request_json_response.assert_called_once_with(
            "https://api.github.com/orgs/edinc/repos?per_page=100",
            None,
        )
        request_json.assert_called_once_with(
            "https://api.github.com/repos/edinc/platform-engineering-landing-zone/contents/catalog-info.yaml",
            None,
        )


if __name__ == "__main__":
    unittest.main()
