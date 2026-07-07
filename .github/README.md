[root](../README.md) / **.github**

GitHub configuration for CI pipelines and dependency automation.

### [Github Actions - Workflows](workflows)

Building and publishing the system image. This is triggered on commits to main.

### [Renovate Config](renovate.json5)

[Renovate](https://docs.renovatebot.com/) is implemented to automate dependacy updates.

It currently tracks pinned software versions in the `versions-*.sh` files in [`build_files`](../build_files). It also tracks pinned SHAs in the Github Actions workflow.

## Notes / Todo


