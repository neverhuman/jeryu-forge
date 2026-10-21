# Contributing

## Pull requests

Outside pull requests are welcome on GitHub. This repository is a read-only
mirror: contributions are gated, reviewed, and merged on the forge, not on
GitHub. After a forge merge, the GitHub pull request is closed with a link to
the forge result, and the mirror receives the merged changes.

The importer is not live yet. For now, we read GitHub pull requests but do not
merge them. Once the importer is live, it will bring GitHub pull requests to
the forge for review.

## Tests and fixtures

Use invented data in all tests and fixtures, such as `acme`, `globex`, and
`service.example`. Never include real site hosts, organization names, logins,
paths, credentials, or other private data.

## Local gate

From the repository root, run:

```sh
JERYU_SPLIT_FULL_CHECK=1 ./ops/ci/check.sh
```

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).
