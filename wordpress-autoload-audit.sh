#!/usr/bin/env bash
# WordPress autoload audit v0.1.0 — Hamza Ahmad Aslam
# SPDX-License-Identifier: MIT
# Queries only; never changes options or outputs option values/names.
set -euo pipefail

if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Usage: bash wordpress-autoload-audit.sh /absolute/wordpress/path options_table' \
    'Example: bash wordpress-autoload-audit.sh /var/www/wordpress wp_options' \
    'Multisite: supply the exact site table, e.g. wp_2_options. No auto-detection.' \
    'Use a staging copy or read replica first. Full-table scans can be expensive.'
  exit 0
fi
if [[ $# != 2 || -z $1 || ! $2 =~ ^[A-Za-z0-9_]+$ || ${#2} -gt 64 ]]; then
  printf '%s\n' 'Expected a WordPress path and an explicit alphanumeric/underscore options table (max 64 characters).' >&2
  exit 2
fi
command -v wp >/dev/null 2>&1 || { printf '%s\n' 'WP-CLI is required.' >&2; exit 127; }
audit_path=$1
audit_table=$2
audit_from="\`$audit_table\`"
audit_autoload="autoload IN ('yes','on','auto-on','auto')"

audit_query() {
  wp --path="$audit_path" --skip-plugins --skip-themes --skip-packages db query "$1" --batch
}

printf '%s\n' 'Autoload audit v0.1.0: stored bytes using WordPress core default autoload values.' \
  'Custom autoload filters and object-cache state are not evaluated.' \
  '150000 bytes is a per-option core default heuristic, not a universal cleanup threshold.' \
  '1. All stored autoload states (including unknown or custom states)'
audit_query "SELECT autoload, COUNT(*) AS option_count, COALESCE(SUM(LENGTH(option_value)),0) AS stored_bytes FROM $audit_from GROUP BY autoload ORDER BY stored_bytes DESC;"

printf '%s\n' '2. Core-default autoload totals'
audit_query "SELECT COUNT(*) AS option_count, COALESCE(SUM(LENGTH(option_value)),0) AS stored_bytes, COALESCE(SUM(CASE WHEN LENGTH(option_value)>150000 THEN 1 ELSE 0 END),0) AS rows_above_default_150000_bytes FROM $audit_from WHERE $audit_autoload;"

printf '%s\n' '3. Largest 20 core-default autoload rows (IDs only; inspect ownership privately)'
audit_query "SELECT option_id, autoload, LENGTH(option_value) AS stored_bytes, CASE WHEN LENGTH(option_value)>150000 THEN 'above_default_heuristic' ELSE 'within_default_heuristic' END AS size_review FROM $audit_from WHERE $audit_autoload ORDER BY stored_bytes DESC, option_id ASC LIMIT 20;"

printf '%s\n' '4. Autoloaded transient-related rows (candidates for review, not proof of leaks)'
audit_query "SELECT COUNT(*) AS transient_related_rows, COALESCE(SUM(LENGTH(option_value)),0) AS stored_bytes FROM $audit_from WHERE $audit_autoload AND (LEFT(option_name,11)='_transient_' OR LEFT(option_name,16)='_site_transient_');"

printf '%s\n' 'Done. Review option ownership and access patterns on staging before changing anything.' \
  'This report does not identify orphaned options, measure PHP memory, or predict TTFB.'
