#  rootless-ubuntu-arc-runner

A minimal ubuntu based Github runner.

Includes:
- Bun
- Deno
- Go
- Node (using node 20 from runner externals)

Expects:
- /tmp and /home/runner to be be mounted as volumes (allowing `readOnlyRootFilesystem: true` on the runner container)
