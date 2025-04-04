#!/bin/bash

# Set a github `token` within the default config file at $HOME/.cr.yaml
cr package orchestrator
cr upload --packages-with-index --push --skip-existing --config $HOME/.cr.yaml
