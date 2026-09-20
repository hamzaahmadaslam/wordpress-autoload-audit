#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/wp" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${AUDIT_TEST_LOG:?}"
query=${*: -2:1}
[[ $query == SELECT* ]]
[[ $query != *UPDATE* ]]
[[ $query != *DELETE* ]]
[[ $query != *option_value\ AS* ]]
printf 'mock result\n'
MOCK
chmod +x "$tmp_dir/wp"

export AUDIT_TEST_LOG="$tmp_dir/calls.log"
PATH="$tmp_dir:$PATH" bash "$repo_dir/wordpress-autoload-audit.sh" /srv/wordpress wp_2_options >"$tmp_dir/output.log"

[[ $(wc -l <"$AUDIT_TEST_LOG") -eq 4 ]]
grep -Fq -- '--path=/srv/wordpress --skip-plugins --skip-themes --skip-packages db query SELECT' "$AUDIT_TEST_LOG"
grep -Fq -- '`wp_2_options`' "$AUDIT_TEST_LOG"
grep -Fq 'Done. Review option ownership' "$tmp_dir/output.log"

if PATH="$tmp_dir:$PATH" bash "$repo_dir/wordpress-autoload-audit.sh" /srv/wordpress 'wp_options;DROP' >/dev/null 2>&1; then
  printf '%s\n' 'Unsafe table name was accepted.' >&2
  exit 1
fi

bash -n "$repo_dir/wordpress-autoload-audit.sh"
printf '%s\n' 'All tests passed.'
