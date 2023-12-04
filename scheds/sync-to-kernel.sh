#!/bin/bash

set -e
shopt -s globstar

if [ $# -ne 1 ]; then
    echo "Usage: sync-to-kernel.sh KERNEL_TREE_TO_SYNC_TO" 1>&2
    exit 1
fi

# We sync all schedulers under kernel-examples but only the following ones
# under rust-user.
rust_scheds=(scx_rusty scx_layered)

headers=($(git ls-files include | grep -v include/vmlinux))
scheds=($(git ls-files kernel-examples ${rust_scheds[@]/#/rust-user/} | grep -v meson.build))
kernel="$1/tools/sched_ext"

echo "Syncing ${#headers[@]} headers and ${#scheds[@]} scheduler source files to $kernel"

srcs=("${headers[@]}" "${scheds[@]}")
dsts=()

# Header paths are the same relative to the base directories.
for file in ${headers[@]}; do
    dsts+=("$kernel/${file}")
done

# Sched files should drop the first directory component. ie.
# kernel-examples/scx_simple.bpf.c should be synced to
# $kernel/scx_simple.bpf.c.
for file in ${scheds[@]}; do
    dsts+=("$kernel/${file#*/}")
done
	    
## debug
#for ((i=0;i<${#srcs[@]};i++)); do
#    echo "${srcs[i]} -> ${dsts[i]}"
#done

nr_missing=0
for dst in "${dsts[@]}"; do
    if [ ! -f "$dst" ]; then
	echo "ERROR: $dst does not exist" 1>&2
	nr_missing=$((nr_missing+1))
    fi
done

if [ $nr_missing -gt 0 ]; then
    exit 1
fi

nr_skipped=0
for ((i=0;i<${#srcs[@]};i++)); do
    src="${srcs[i]}"
    dst="${dsts[i]}"
    orig="$src"

    #
    # As scx_utils is in this repo, rust-user schedulers point directly to
    # the source in the tree. As they break outside this tree, drop them
    # before syncing Cargo.toml files.
    #
    if [[ "$src" == */Cargo.toml ]]; then
	tmp=$(mktemp)
	sed -r 's/^scx_utils =.*version\s*=\s*"([^"]*)".*$/scx_utils = \"\1"/' < "$src" > "$tmp"
	src="$tmp"
    fi

    if cmp -s "$src" "$dst"; then
	nr_skipped=$((nr_skipped+1))
	continue
    fi
    if [[ "$orig" == */Cargo.toml ]]; then
	echo "Syncing $orig (dropped path from scx_utils dependency)"
    else
	echo "Syncing $orig"
    fi
    cp -f "$src" "$dst"
done

echo "Skipped $nr_skipped unchanged files"
