# Bifrost profile — stores all user server and alias definitions.
# Copy this file to ~/.config/bifrost/profile.sh and replace with your real infrastructure.
#
# SERVER_ENTRIES format: "name|host|user|port"
# ALIAS_ENTRIES format: "alias|server-name"

SERVER_ENTRIES=(
	"example-prod|203.0.113.10|admin|22"
	"example-dev|198.51.100.20|devuser|22"
)

ALIAS_ENTRIES=(
	"prod|example-prod"
	"dev|example-dev"
)

# Tip: Keep real infrastructure credentials and IPs in this local file, not in Git.
# The bifrost.sh script contains no embedded defaults; it loads everything from here.
