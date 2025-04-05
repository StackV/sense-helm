#!/bin/bash

# Example Conf:
# token: GITHUB_TOKEN
# owner: StackV
# git-repo: sense-helm

cr package orchestrator
cr package keycloak
cr upload --packages-with-index --push --skip-existing --config $HOME/.cr.yaml
cr index --packages-with-index --index-path . --push --config $HOME/.cr.yaml
