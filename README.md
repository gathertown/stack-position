# Stack position

Runs CI once per stack of PRs, on the top PR. On a PR with an open PR stacked on it, the action sets `skip` to `true`. Gate your expensive jobs on it, and the top PR's run covers every PR below it.

It reads only each PR's base branch, so it works with Graphite or any tool that bases each PR on the one below.

## Usage

```yaml
jobs:
  stack-position:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    outputs:
      skip: ${{ steps.position.outputs.skip }}
    steps:
      - id: position
        if: github.event_name == 'pull_request'
        uses: gathertown/stack-position@v1
  test:
    needs: stack-position
    if: needs.stack-position.outputs.skip != 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "your tests"
```

A job skipped by its `if:` reports `skipped`, which passes a required check. On a push, the step's `if:` skips it, and an empty `skip` runs the job.

## How it decides

`skip` is `true` only when all of these hold:

- An open PR is based on this PR's head branch, and its head contains this PR's head commit. A PR above that hasn't been restacked onto the latest push doesn't count.
- That PR's branch doesn't start with `ci/`. Bots open fix PRs on `ci/` branches that never run CI.
- This PR has no `ci/run-full` label.

Anything else sets `skip` to `false`, including a failed API call. A broken lookup runs CI.

The action waits 60 seconds first, because `gt submit` pushes the PRs above this one after it.

## Run CI below the top

Create a `ci/run-full` label in your repo. Add it to a PR, then re-run the skipped workflows. The action reads labels at run time, so no new commit is needed. Every later push on that PR runs full while the label stays.

## Inputs

| Input          | Default        | Description                                                                                        |
| -------------- | -------------- | -------------------------------------------------------------------------------------------------- |
| `github-token` | `github.token` | Lists PRs, reads labels and compares commits. Needs `contents: read` and `pull-requests: read`. |

## Outputs

| Output | Description                                                                                  |
| ------ | -------------------------------------------------------------------------------------------- |
| `skip` | `'true'` when an open PR above contains this PR's head and there's no `ci/run-full` label |

## Releasing

Push a `vX.Y.Z` tag on `main`. CI moves `vX` to it once shellcheck passes.

## License

MIT
