#!/bin/bash

# Example Conf:
# token: GITHUB_TOKEN
# owner: StackV
# git-repo: sense-helm

./updateReadme.sh

cr package orchestrator
cr package keycloak
git pull
cr upload --packages-with-index --push --skip-existing --config $HOME/.cr.yaml
cr index --packages-with-index --index-path . --push --config $HOME/.cr.yaml
