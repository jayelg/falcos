# variants/<name>.sh — pin/flag overrides selected as `<module>@<name>` in
# modules.list (e.g. `template@example`). OPTIONAL. Sourced after
# versions.sh and before module.sh, so it can override a pin or set a flag
# that module.sh then branches on.

# shellcheck disable=SC2034  # consumed by module.sh
TEMPLATE_VERSION="1.0.0-example"
