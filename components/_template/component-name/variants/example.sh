# variants/<name>.sh — pin/flag overrides selected as `<component>@<name>` in
# components.list (e.g. `template@example`). OPTIONAL. Sourced after
# versions.sh and before component.sh, so it can override a pin or set a flag
# that component.sh then branches on.

# shellcheck disable=SC2034  # consumed by component.sh
TEMPLATE_VERSION="1.0.0-example"
