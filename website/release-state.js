export const GITHUB_REPOSITORY_URL = "https://github.com/zongzack/zongMacTools";
export const GITHUB_RELEASES_URL = `${GITHUB_REPOSITORY_URL}/releases`;
export const GITHUB_RELEASES_API_URL = "https://api.github.com/repos/zongzack/zongMacTools/releases?per_page=10";

function isValidDate(value) {
  return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

function isMatchingDownloadUrl(value, tagName, assetName) {
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
      pathSegments.length === 7 &&
      pathSegments[0] === "" &&
      pathSegments[1] === "zongzack" &&
      pathSegments[2] === "zongMacTools" &&
      pathSegments[3] === "releases" &&
      pathSegments[4] === "download" &&
      pathSegments[5] === tagName &&
      pathSegments[6] === assetName
    );
  } catch {
    return false;
  }
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
    !isValidDate(release.published_at) ||
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

function localizedReleaseDate(isoDate) {
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric"
  }).format(new Date(isoDate));
}

export function releaseStateFrom(releases) {
  if (!Array.isArray(releases)) {
    return {
      kind: "unavailable",
      label: "暂时无法获取版本信息，可在 GitHub 查看最新状态"
    };
  }

  for (const release of releases) {
    const candidate = releaseCandidate(release);
    if (candidate.kind === "invalid") {
      return {
        kind: "unavailable",
        label: "暂时无法获取版本信息，可在 GitHub 查看最新状态"
      };
    }

    if (candidate.kind === "available") {
      const version =
        typeof candidate.release.tag_name === "string" && candidate.release.tag_name
          ? candidate.release.tag_name
          : "最新版本";
      return {
        kind: "available",
        label: `${version} 已发布于 ${localizedReleaseDate(candidate.release.published_at)}`,
        assetUrl: candidate.asset.browser_download_url
      };
    }
  }

  return { kind: "pending", label: "公开测试版即将发布" };
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
    return {
      kind: "unavailable",
      label: "暂时无法获取版本信息，可在 GitHub 查看最新状态"
    };
  }
}
