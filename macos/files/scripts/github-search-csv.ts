#!/usr/bin/env -S deno run --allow-net --allow-env

// GitHub Search to CSV
// Usage: deno run --allow-net --allow-env github-search-csv.ts 'is:pr author:username created:2025-07-01..2025-12-31'

interface SearchResult {
  html_url: string;
  title: string;
  repository_url: string;
  number: number;
  pull_request?: { url: string };
  user: { login: string } | null;
}

interface SearchResponse {
  items: SearchResult[];
  total_count: number;
}

interface Review {
  user: { login: string } | null;
}

interface Comment {
  user: { login: string } | null;
}

const GITHUB_API = "https://api.github.com";

function getToken(): string {
  const token = Deno.env.get("GITHUB_TOKEN");
  if (!token) {
    console.error("Error: GITHUB_TOKEN environment variable is required");
    Deno.exit(1);
  }
  return token;
}

async function githubFetch<T>(url: string, token: string): Promise<T> {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`GitHub API error: ${response.status} ${text}`);
  }

  return response.json();
}

async function searchIssues(
  query: string,
  token: string
): Promise<SearchResult[]> {
  const results: SearchResult[] = [];
  let page = 1;
  const perPage = 100;

  while (true) {
    const url = `${GITHUB_API}/search/issues?q=${encodeURIComponent(query)}&per_page=${perPage}&page=${page}`;
    const response = await githubFetch<SearchResponse>(url, token);

    results.push(...response.items);

    if (response.items.length < perPage || results.length >= response.total_count) {
      break;
    }
    page++;
  }

  return results;
}

async function getPRReviewers(
  owner: string,
  repo: string,
  prNumber: number,
  token: string
): Promise<string[]> {
  const url = `${GITHUB_API}/repos/${owner}/${repo}/pulls/${prNumber}/reviews`;
  try {
    const reviews = await githubFetch<Review[]>(url, token);
    const reviewers = reviews
      .map((r) => r.user?.login)
      .filter((login): login is string => !!login);
    return [...new Set(reviewers)];
  } catch {
    return [];
  }
}

async function getIssueCommenters(
  owner: string,
  repo: string,
  issueNumber: number,
  token: string
): Promise<string[]> {
  const url = `${GITHUB_API}/repos/${owner}/${repo}/issues/${issueNumber}/comments`;
  try {
    const comments = await githubFetch<Comment[]>(url, token);
    const commenters = comments
      .map((c) => c.user?.login)
      .filter((login): login is string => !!login);
    return [...new Set(commenters)];
  } catch {
    return [];
  }
}

async function getPRReviewCommenters(
  owner: string,
  repo: string,
  prNumber: number,
  token: string
): Promise<string[]> {
  const url = `${GITHUB_API}/repos/${owner}/${repo}/pulls/${prNumber}/comments`;
  try {
    const comments = await githubFetch<Comment[]>(url, token);
    const commenters = comments
      .map((c) => c.user?.login)
      .filter((login): login is string => !!login);
    return [...new Set(commenters)];
  } catch {
    return [];
  }
}

function parseRepoUrl(repositoryUrl: string): { owner: string; repo: string } {
  // repository_url format: https://api.github.com/repos/{owner}/{repo}
  const parts = repositoryUrl.split("/");
  return {
    owner: parts[parts.length - 2],
    repo: parts[parts.length - 1],
  };
}

function escapeCSV(field: string): string {
  if (field.includes('"') || field.includes(",") || field.includes("\n")) {
    return `"${field.replace(/"/g, '""')}"`;
  }
  return field;
}

interface ProcessedItem {
  url: string;
  org: string;
  repo: string;
  title: string;
  author: string;
  reviewers: Set<string>;
}

async function main() {
  const args = Deno.args;

  if (args.length === 0) {
    console.error(
      "Usage: deno run --allow-net --allow-env github-search-csv.ts '<search-query>'"
    );
    console.error(
      "Example: deno run --allow-net --allow-env github-search-csv.ts 'is:pr author:username created:2025-07-01..2025-12-31'"
    );
    Deno.exit(1);
  }

  const query = args[0];
  const token = getToken();

  console.error(`Searching for: ${query}`);

  const results = await searchIssues(query, token);
  console.error(`Found ${results.length} results`);

  // Process all items and collect all unique reviewers
  const processedItems: ProcessedItem[] = [];
  const allUniqueReviewers = new Set<string>();

  for (const item of results) {
    const { owner, repo } = parseRepoUrl(item.repository_url);
    const isPR = !!item.pull_request;

    const itemReviewers = new Set<string>();

    // Fetch reviewers/commenters
    if (isPR) {
      const reviewers = await getPRReviewers(owner, repo, item.number, token);
      const reviewCommenters = await getPRReviewCommenters(
        owner,
        repo,
        item.number,
        token
      );
      reviewers.forEach((r) => itemReviewers.add(r));
      reviewCommenters.forEach((r) => itemReviewers.add(r));
    }

    const commenters = await getIssueCommenters(
      owner,
      repo,
      item.number,
      token
    );
    commenters.forEach((r) => itemReviewers.add(r));

    // Add to global set
    itemReviewers.forEach((r) => allUniqueReviewers.add(r));

    processedItems.push({
      url: item.html_url,
      org: owner,
      repo: repo,
      title: item.title,
      author: item.user?.login || "",
      reviewers: itemReviewers,
    });
  }

  // Sort reviewers alphabetically for consistent column order
  const sortedReviewers = [...allUniqueReviewers].sort();

  // Output CSV header
  const headerParts = ["url", "org", "repo", "title", "author", ...sortedReviewers.map(escapeCSV)];
  console.log(headerParts.join(","));

  // Output CSV rows
  for (const item of processedItems) {
    const row = [
      escapeCSV(item.url),
      escapeCSV(item.org),
      escapeCSV(item.repo),
      escapeCSV(item.title),
      escapeCSV(item.author),
    ];

    // Add a column for each reviewer (X if they reviewed, empty if not)
    for (const reviewer of sortedReviewers) {
      row.push(item.reviewers.has(reviewer) ? "X" : "");
    }

    console.log(row.join(","));
  }
}

main();
