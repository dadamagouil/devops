#!/usr/bin/env bash
# Checks the formatting of the Dart code (dart format). Run by CI and before every push.
#   check_format.sh [app-dir]        app-dir defaults to the current directory
# Generated localisation files (gen-l10n) are excluded: Flutter produces them itself.
# Needs `flutter pub get` first, otherwise analysis_options.yaml is only partly read (flutter_lints is missing)
# and the project's page width is ignored.
# To fix instead of check, run: dart format $(git ls-files '*.dart' | grep -v 'l10n/app_localizations')
set -euo pipefail
cd "${1:-.}"
files=$(git ls-files '*.dart' | grep -v 'l10n/app_localizations')
# shellcheck disable=SC2086  # we do want a list of space separated files
dart format --output=none --set-exit-if-changed $files
