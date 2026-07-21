# falcos-tools — the essential falcos CLI framework: the falcos-cli OS TUI
# and the `just` engine behind the component justfile.inc recipe mechanism.
# Deliberately KDE-independent so it can lead components.list as part of a
# minimal build. The OS self-update + signing mechanism lives in the
# auto-updates component; the bootc-updates KDE GUI it used to bundle now
# lives in de/falcos-plasma-settings (runs after kde-desktop).

### falcos-cli — the OS TUI and the justfile framework it drives
# Runtime dependencies of the framework, installed here so a minimal
# base+falcos-tools build stays self-contained:
#   just      -- engine for the component justfile.inc recipe mechanism
#                (recipes appended to /usr/share/falcos/justfile.apps via
#                lib/run-component.sh)
#   fastfetch -- the falcos-cli TUI system panel
dnf5 install -y just fastfetch

source /ctx/lib/fetch-helpers.sh

# falcos-cli: OS TUI, aliased to the OS name via files/etc/profile.d/falcos-cli.sh.
# The release's install.sh also drops the runtime helper falcos-helpers.sh;
# falcos-progress and the base justfile ship in this component's files/ overlay.
fetch_extract "https://github.com/jayelg/falcos-cli/releases/download/v${FALCOS_CLI_VERSION}/falcos-cli-v${FALCOS_CLI_VERSION}-x86_64-linux-gnu.tar.gz" \
    "$FALCOS_CLI_SHA256" /tmp
bash /tmp/install.sh
rm -rf /tmp/falcos-cli /tmp/install.sh /tmp/scripts/
