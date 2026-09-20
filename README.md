# WordPress autoload audit

A small WP-CLI/Bash diagnostic by [Hamza Ahmad Aslam](https://hamzaahmadaslam.com/). Version 0.1.0.

## What it reports

- Counts and stored bytes for every autoload state.
- Totals for the core-default states `yes`, `on`, `auto-on`, and `auto`.
- The largest 20 matching rows, identified by option ID.
- Counts and bytes for autoloaded transient-related rows. These are review candidates, not confirmed leaks.

The script issues SELECT queries only. It never updates or deletes options, flushes caches, or prints option names or values. It contains no telemetry or outbound reporting.

## Use

Requires Bash, WP-CLI, its MySQL/MariaDB client, and access to a WordPress installation. Review the source first and use a staging copy or read replica; these queries scan the options table. WP-CLI loads local configuration, so use only a trusted installation/configuration. Read-only database permissions provide an additional safeguard.

```bash
bash wordpress-autoload-audit.sh /var/www/wordpress wp_options
```

Supply the actual table name. For multisite, select the exact site's options table, such as `wp_2_options`; the script does not infer it from a URL. Network-level `sitemeta` is outside its scope.

## Interpret correctly

WordPress 6.6 introduced a default **150000-byte** per-option heuristic. The relevant threshold filter is `wp_max_autoloaded_option_size`; `wp_filter_default_autoload_value_via_option_size()` is the core callback. This is not a blanket rule to delete or disable large options, and it does not retroactively rewrite every stored row. Explicit settings and site-specific filters matter.

This audit uses stored states and the core default set. It does not execute runtime filters, inspect object-cache contents, identify orphaned data, or measure deserialized PHP memory or response time. Its default-threshold flag is informational and may differ from a site's configured threshold. Never infer performance gains from byte counts alone.

To investigate a listed option ID, inspect its name and owning plugin privately on staging. Establish whether it is needed on most requests, reproduce the workload, and use the supported WordPress/plugin API for any later change. This tool deliberately generates no mutation queries.

## Validation status

Bash syntax, table-name validation, query count, and SELECT-only behavior are covered by `tests/run.sh` and GitHub Actions. Database integration testing on WordPress/MySQL is still required before describing the utility as production-validated.

```bash
bash tests/run.sh
```

## References

- [WordPress core size heuristic](https://developer.wordpress.org/reference/functions/wp_filter_default_autoload_value_via_option_size/)
- [Core autoload states](https://developer.wordpress.org/reference/functions/wp_autoload_values_to_autoload/)
- [WP-CLI database query command and multisite caveat](https://developer.wordpress.org/cli/commands/db/query/)

## License

[MIT](LICENSE) © 2026 Hamza Ahmad Aslam.
