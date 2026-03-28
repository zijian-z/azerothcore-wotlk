# Docker

This repository now ships a Docker deployment that follows the official
AzerothCore classic installation flow, but moves the build, database bootstrap,
configuration injection, and `Data.zip` preparation into containers.

Deployment details are documented in
[`doc/DOCKER_CLASSIC_DEPLOYMENT_CN.md`](../../doc/DOCKER_CLASSIC_DEPLOYMENT_CN.md).

The previous multi-profile Docker setup has been intentionally removed. Images
are expected to be built and published through the manual GitHub Actions
workflow, then referenced locally from `.env`.
