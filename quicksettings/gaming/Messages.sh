#! /usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Marco Allegretti
# SPDX-License-Identifier: EUPL-1.2

set -e
: "${XGETTEXT:?XGETTEXT is not set}"
: "${podir:?podir is not set}"

mapfile -t files < <(find . \( -name '*.js' -o -name '*.qml' -o -name '*.cpp' \) -print)
if [[ ${#files[@]} -eq 0 ]]; then
	echo "Messages.sh: no input files found" >&2
	exit 1
fi

"$XGETTEXT" "${files[@]}" -o "$podir/plasma_org.kde.plasma.quicksetting.gaming.pot"
