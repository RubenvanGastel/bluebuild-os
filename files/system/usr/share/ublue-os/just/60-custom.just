# Custom ujust recipes (run with: ujust <name>)

# Install Claude Code for the current user (~/.local/bin, auto-updates itself)
install-claude-code:
    #!/usr/bin/env bash
    set -euo pipefail
    curl -fsSL https://claude.ai/install.sh | bash
    echo "Done. Open a new terminal and run: claude"
