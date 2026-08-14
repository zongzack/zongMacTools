export const GITHUB_REPOSITORY_URL = "https://github.com/zongzack/zongMacTools";
export const GITHUB_RELEASES_URL = `${GITHUB_REPOSITORY_URL}/releases`;
export const GITHUB_RELEASES_API_URL = "https://api.github.com/repos/zongzack/zongMacTools/releases?per_page=10";

function isValidPublishedAt(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)) {
    return false;
  }

  const date = new Date(value);
  return !Number.isNaN(date.getTime()) && date.toISOString() === value.replace("Z", ".000Z");
}

function isMatchingGitHubReleaseUrl(value, expectedPathSegments) {
  if (typeof value !== "string") {
    return false;
  }

  try {
    const url = new URL(value);
    const pathSegments = url.pathname.split("/").map(decodeURIComponent);
    return (
      url.protocol === "https:" &&
      url.hostname === "github.com" &&
      url.search === "" &&
      url.hash === "" &&
      pathSegments.length === expectedPathSegments.length &&
      pathSegments.every((segment, index) => segment === expectedPathSegments[index])
    );
  } catch {
    return false;
  }
}

function isMatchingDownloadUrl(value, tagName, assetName) {
  return isMatchingGitHubReleaseUrl(value, ["", "zongzack", "zongMacTools", "releases", "download", tagName, assetName]);
}

function isMatchingReleaseUrl(value, tagName) {
  return isMatchingGitHubReleaseUrl(value, ["", "zongzack", "zongMacTools", "releases", "tag", tagName]);
}

function releaseCandidate(release) {
  if (!release || typeof release !== "object" || typeof release.draft !== "boolean") {
    return { kind: "invalid" };
  }

  if (release.draft) {
    return { kind: "skip" };
  }

  if (
    typeof release.tag_name !== "string" ||
    release.tag_name.length === 0 ||
    !isValidPublishedAt(release.published_at) ||
    !isMatchingReleaseUrl(release.html_url, release.tag_name) ||
    !Array.isArray(release.assets)
  ) {
    return { kind: "invalid" };
  }

  const matchingAssets = release.assets.filter(
    (asset) => typeof asset?.name === "string" && /^zongMacTools-.+\.zip$/i.test(asset.name)
  );

  if (
    matchingAssets.some(
      (asset) => !isMatchingDownloadUrl(asset.browser_download_url, release.tag_name, asset.name)
    )
  ) {
    return { kind: "invalid" };
  }

  const asset = matchingAssets[0];
  return asset ? { kind: "available", release, asset } : { kind: "skip" };
}

export function releaseStateFrom(releases) {
  if (!Array.isArray(releases)) {
    return { kind: "unavailable" };
  }

  for (const release of releases) {
    const candidate = releaseCandidate(release);
    if (candidate.kind === "invalid") {
      return { kind: "unavailable" };
    }

    if (candidate.kind === "available") {
      return {
        kind: "available",
        tagName: candidate.release.tag_name,
        publishedAt: candidate.release.published_at,
        assetUrl: candidate.asset.browser_download_url,
        releaseUrl: candidate.release.html_url
      };
    }
  }

  return { kind: "pending" };
}

export async function fetchReleaseState(fetcher = fetch) {
  try {
    const response = await fetcher(GITHUB_RELEASES_API_URL, {
      headers: { Accept: "application/vnd.github+json" }
    });

    if (!response.ok) {
      throw new Error(`GitHub release request failed: ${response.status}`);
    }

    return releaseStateFrom(await response.json());
  } catch {
    return { kind: "unavailable" };
  }
}
