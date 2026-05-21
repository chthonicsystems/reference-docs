---
library: support
version: 0.1.0
related-rfcs: [0016]
last-verified: 2026-05-22
tags: [support, github]
summary: GitHubIssueTrackerProvider — creates GitHub issues from support tickets via Octokit.
---

# GitHub sync (`Chthonic.Support.GitHub`)

Phase-1 implementation. Uses Octokit (.NET GitHub SDK) to create + update issues.

## Setup

```bash
GITHUB_SUPPORT_TOKEN=ghp_...                         # repo + issues scope
GITHUB_SUPPORT_DEFAULT_REPO=chthonicsystems/torquetech
```

## Create flow

When a ticket matches a CTI with `external_provider='github'`:

```
1. Build issue body from ticket fields (markdown).
2. Octokit POST /repos/{owner}/{repo}/issues
3. Store issue HTML URL → support_ticket.external_issue_id
4. Set issue labels: 'support', '<category>', '<type>'.
```

## Issue body template

```markdown
**Tenant:** {{ system.name }} (system_id={{ system_id }})
**Reported by:** {{ user.email }} (user_id={{ user_id }})
**CTI:** {{ category }} / {{ type }} / {{ item }}

---

{{ body }}

---

[View in app](#) (URL is `{{ ticket_url }}` in template)
```

## Closing the loop

When admins close the ticket (Resolved → Closed), the provider closes the GitHub issue + adds a closing comment with the resolution.

## Rate limits

GitHub: 5000 requests/hour per token. Single-token deployments rarely hit this (support tickets are infrequent compared to API rate). For higher volumes, swap to a GitHub App token (10x rate).

## Related

- [`issue-tracker-abstraction.md`](issue-tracker-abstraction.md), [`cti-routing.md`](cti-routing.md).
