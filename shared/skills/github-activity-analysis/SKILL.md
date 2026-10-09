---
name: github-activity-analysis
description: Analyzes a GitHub user's contributions, pull requests, reviews, issues, and commits within an organization over a configurable time period.
---

# GitHub Activity Analysis

Generates a comprehensive report of a GitHub user's activity within an organization, including PRs authored, PRs reviewed, issues created, comments made, and commits across repositories.

## When to Use This Skill

- Performance reviews or self-assessments
- Understanding contribution patterns
- Tracking work done during a specific period
- Generating activity reports for stakeholders
- Analyzing collaboration patterns (who reviews whom)
- Identifying active repositories for a contributor

## What This Skill Does

1. **Collects Data**: Queries GitHub for PRs, issues, reviews, comments, and commits
2. **Aggregates Results**: Groups data by repository and author
3. **Analyzes Patterns**: Identifies review relationships and work themes
4. **Generates Report**: Creates a structured summary with statistics and breakdowns

## How to Use

### Basic Usage

```
Analyze my GitHub activity in stellar for 2025
```

```
Generate activity report for user johndoe in acme-corp from 2025-01-01 to 2025-06-30
```

### With Specific Parameters

The skill will ask for any missing parameters:
- **Username**: GitHub username to analyze
- **Organization**: GitHub org to search within
- **Start Date**: Beginning of date range (yyyy-mm-dd)
- **End Date**: End of date range (yyyy-mm-dd)

## Workflow

### 1. Gather Parameters

If not provided, ask the user for:
- GitHub username
- Organization name
- Date range (start and end dates)

### 2. Execute Parallel Data Collection

Run these GitHub API searches in parallel:

**PRs Authored:**
```
mcp__github__search_pull_requests
  query: "author:{USERNAME} org:{ORG} created:{START_DATE}..{END_DATE}"
  perPage: 100
```

**PRs Reviewed:**
```
mcp__github__search_pull_requests
  query: "reviewed-by:{USERNAME} org:{ORG} created:{START_DATE}..{END_DATE}"
  perPage: 100
```

**PRs Commented On:**
```
mcp__github__search_pull_requests
  query: "commenter:{USERNAME} org:{ORG} created:{START_DATE}..{END_DATE}"
  perPage: 100
```

**Issues Created:**
```
mcp__github__search_issues
  query: "author:{USERNAME} org:{ORG} created:{START_DATE}..{END_DATE}"
  perPage: 100
```

**Issues Commented On:**
```
mcp__github__search_issues
  query: "commenter:{USERNAME} org:{ORG} created:{START_DATE}..{END_DATE}"
  perPage: 100
```

### 3. Identify Active Repositories

From the PR data, extract the unique repositories where the user is active.

### 4. Query Commits Per Repository

For each active repository:
```
mcp__github__list_commits
  owner: {ORG}
  repo: {REPO}
  author: {USERNAME}
  perPage: 100
```

Filter commits by date range since the API doesn't support date filtering directly.

### 5. Process and Aggregate Data

**Group PRs by Repository:**
Extract repository names and count PRs per repo.

**Group Reviews by PR Author:**
For PRs reviewed, group by the PR author to show collaboration patterns.

**Filter Commits by Date:**
Ensure commits fall within the specified date range.

### 6. Generate Summary Report

Present the findings with these sections:

**Header:**
- User: {USERNAME}
- Organization: {ORG}
- Period: {START_DATE} to {END_DATE}

**Summary Statistics:**
- PRs Authored: {count}
- PRs Reviewed: {count}
- PRs Commented On: {count}
- Issues Created: {count}
- Issues Commented On: {count}
- Total Commits: {count}

**PRs Authored by Repository (CSV):**
```
Repository,Count
{repo},{count}
```

**PRs Reviewed by Repository (CSV):**
```
Repository,Count
{repo},{count}
```

**Review Activity by PR Author (CSV):**
```
PR Author,PRs Reviewed,Percentage
{author},{count},{pct}
```

**Commits by Repository (CSV):**
```
Repository,Commits
{repo},{count}
```

**PRs Created (CSV):**
```
#,Repository,Title,State,Date
{number},{repo},{title},{state},{date}
```

**Issues Created (CSV):**
```
#,Repository,Title,Date
{number},{repo},{title},{date}
```

**Key Work Themes:**
Analyze the actual PR titles and commit messages to extract specific recurring topics. Group related work and list concrete themes found in the data, not generic categories.

## Notes

- GitHub search API returns max 1000 results per query
- For high-volume contributors, results may be truncated
- The "reviewed-by" qualifier finds PRs where the user submitted a formal review
- The "commenter" qualifier finds items where the user left any comment
- Commit counts are filtered client-side since the API doesn't support date ranges
