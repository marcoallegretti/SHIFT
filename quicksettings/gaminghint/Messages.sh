#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marco Allegretti
# SPDX-License-Identifier: EUPL-1.2

set -e
: "${XGETTEXT:?XGETTEXT is not set}"
: "${podir:?podir is not set}"

shopt -s nullglob
files=(*.json contents/ui/*.qml)
if [[ ${#files[@]} -eq 0 ]]; then
    echo "Messages.sh: no input files found" >&2
    exit 1
fi
"$XGETTEXT" "${files[@]}" -o "$podir/plasma_mobile_qt.pot"
