#!/bin/bash

set -e

function main {
  for rev in `revisions`; do
    echo;
    echo "revision: $rev";
    echo "files: `files`";
    echo "----SEPERATOR----";
  done
}

function revisions {
  git log --reverse --oneline --topo-order | cut -d ' ' -f 1
}

function long_hash {
  git rev-parse $rev
}

function files {
  git diff-tree --no-commit-id -r -M -c --name-status --root $rev
}

main

