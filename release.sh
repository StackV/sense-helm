#!/bin/bash

# Example Usage:
# ./release.sh orchestrator

# Example Conf:
# token: GITHUB_TOKEN
# owner: StackV
# git-repo: sense-helm

cr package $1
git pull
cr upload --packages-with-index --push --skip-existing --config $HOME/.cr.yaml
cr index --packages-with-index --index-path . --push --config $HOME/.cr.yaml
