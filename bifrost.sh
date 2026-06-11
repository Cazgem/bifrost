#!/bin/bash
#
#######################
#					  #
#	  DIVISI LABS	  #
#	Bifrost v 3.3.0	  #
#					  #
#######################
#
# This script is used to Connect to Virtual Hosts.
# Created by Cazgem from https://cazgem.com
# Feel free to modify it and Contribute at https://github.com/Cazgem/bifrost
#
#
#
### PARAMETERS ###
VERSION="3.3.0"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
PROFILE_FILE="${BIFROST_PROFILE:-$HOME/.config/bifrost/profile.sh}"
INSTALL_DIR="${BIFROST_INSTALL_DIR:-/usr/bin}"
INSTALL_PATH="$INSTALL_DIR/bifrost"
GITHUB_REPO="${BIFROST_GITHUB_REPO:-Cazgem/bifrost}"
GITHUB_TOKEN="${BIFROST_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
RELEASE_ASSET_NAME="${BIFROST_RELEASE_ASSET:-bifrost.sh}"
CHECKSUM_ASSET_NAME="${BIFROST_CHECKSUM_ASSET:-SHA256SUMS}"

# Entry-based defaults (name|host|user|port) make reordering and updates simpler.
SERVER_ENTRIES=(
	"example-prod|203.0.113.10|admin|22"
	"example-dev|198.51.100.20|devuser|22"
)

# Alias entries use alias|server-name so aliases survive server reorder.
ALIAS_ENTRIES=(
	"prod|example-prod"
	"dev|example-dev"
)

SRVNAME=()
SRVHOST=()
SRVUSER=()
SRVPORT=()
ALIAS_NAME=()
ALIAS_TARGET=()

TOTAL=0
LIMIT=0

###################

refresh_totals(){
	TOTAL=${#SRVNAME[@]}
	LIMIT=$((TOTAL - 1))
}
find_server_index_by_name(){
	lookup="${1,,}"
	for (( i=0; i<${#SRVNAME[@]}; i++ )); do
		if [[ "${SRVNAME[$i],,}" == "$lookup" ]]; then
			echo "$i"
			return 0
		fi
	done

	return 1
}
build_servers_from_entries(){
	SRVNAME=()
	SRVHOST=()
	SRVUSER=()
	SRVPORT=()

	for entry in "${SERVER_ENTRIES[@]}"; do
		IFS='|' read -r name host user port <<< "$entry"

		if [[ -z "$name" || -z "$host" ]]; then
			echo -e "${RED}Profile error:${NC} invalid server entry '$entry'"
			exit 1
		fi

		if [[ -z "$port" ]]; then
			port=22
		fi

		SRVNAME+=("$name")
		SRVHOST+=("$host")
		SRVUSER+=("$user")
		SRVPORT+=("$port")
	done
}
build_aliases_from_entries(){
	ALIAS_NAME=()
	ALIAS_TARGET=()

	for alias_entry in "${ALIAS_ENTRIES[@]}"; do
		IFS='|' read -r alias_name alias_target_name <<< "$alias_entry"

		if [[ -z "$alias_name" || -z "$alias_target_name" ]]; then
			echo -e "${RED}Profile error:${NC} invalid alias entry '$alias_entry'"
			exit 1
		fi

		target_idx="$(find_server_index_by_name "$alias_target_name")"
		if [[ $? -ne 0 ]]; then
			echo -e "${RED}Profile error:${NC} alias target '$alias_target_name' not found"
			exit 1
		fi

		ALIAS_NAME+=("$alias_name")
		ALIAS_TARGET+=("$target_idx")
	done
}
validate_profile(){
	if (( ${#SRVNAME[@]} == 0 || ${#SRVHOST[@]} == 0 || ${#SRVPORT[@]} == 0 )); then
		echo -e "${RED}Profile error:${NC} server arrays cannot be empty."
		exit 1
	fi

	if (( ${#SRVNAME[@]} != ${#SRVHOST[@]} || ${#SRVNAME[@]} != ${#SRVUSER[@]} || ${#SRVNAME[@]} != ${#SRVPORT[@]} )); then
		echo -e "${RED}Profile error:${NC} SRVNAME, SRVHOST, SRVUSER, SRVPORT must have matching lengths."
		exit 1
	fi

	if (( ${#ALIAS_NAME[@]} != ${#ALIAS_TARGET[@]} )); then
		echo -e "${RED}Profile error:${NC} ALIAS_NAME and ALIAS_TARGET must have matching lengths."
		exit 1
	fi
}
load_profile(){
	if [[ -f "$PROFILE_FILE" ]]; then
		# shellcheck source=/dev/null
		source "$PROFILE_FILE"
	fi

	# Preferred modern format.
	if (( ${#SERVER_ENTRIES[@]} > 0 )); then
		build_servers_from_entries
	fi

	if (( ${#ALIAS_ENTRIES[@]} > 0 )); then
		build_aliases_from_entries
	fi

	validate_profile
	refresh_totals
}
write_default_profile(){
	profile_dir="$(dirname "$PROFILE_FILE")"
	mkdir -p "$profile_dir"

	if [[ -f "$PROFILE_FILE" ]]; then
		return 0
	fi

	cat > "$PROFILE_FILE" <<'EOF'
# Bifrost profile
# Preferred format:
# SERVER_ENTRIES: name|host|user|port
# ALIAS_ENTRIES: alias|server-name
# Keep real infrastructure values in this local file, not in the Git repository.

SERVER_ENTRIES=(
	"example-prod|203.0.113.10|admin|22"
	"example-dev|198.51.100.20|devuser|22"
)

ALIAS_ENTRIES=(
	"prod|example-prod"
	"dev|example-dev"
)

# Legacy arrays are still supported if you prefer that style:
# SRVNAME=()
# SRVHOST=()
# SRVUSER=()
# SRVPORT=()
# ALIAS_NAME=()
# ALIAS_TARGET=()
EOF
}
run_as_installer(){
	if [[ -w "$INSTALL_DIR" || ! -e "$INSTALL_DIR" ]]; then
		"$@"
		return $?
	fi

	if command -v sudo >/dev/null 2>&1; then
		sudo "$@"
		return $?
	fi

	echo -e "${RED}Install failed:${NC} insufficient permissions for $INSTALL_DIR and sudo not found."
	return 1
}
install_binary(){
	run_as_installer mkdir -p "$INSTALL_DIR" || return 1
	run_as_installer cp "$SCRIPT_PATH" "$INSTALL_PATH" || return 1
	run_as_installer chmod 755 "$INSTALL_PATH" || return 1
}
fetch_url(){
	url="$1"
	ua_header="User-Agent: bifrost/$VERSION"
	accept_header="Accept: application/vnd.github+json"

	if command -v curl >/dev/null 2>&1; then
		if [[ -n "$GITHUB_TOKEN" ]]; then
			curl -fsSL -H "$ua_header" -H "$accept_header" -H "Authorization: Bearer $GITHUB_TOKEN" "$url" 2>/dev/null
		else
			curl -fsSL -H "$ua_header" -H "$accept_header" "$url" 2>/dev/null
		fi
		return $?
	fi

	if command -v wget >/dev/null 2>&1; then
		if [[ -n "$GITHUB_TOKEN" ]]; then
			wget -qO- --header="$ua_header" --header="$accept_header" --header="Authorization: Bearer $GITHUB_TOKEN" "$url" 2>/dev/null
		else
			wget -qO- --header="$ua_header" --header="$accept_header" "$url" 2>/dev/null
		fi
		return $?
	fi

	echo -e "${RED}Update check failed:${NC} curl or wget is required."
	return 1
}
download_url_to_file(){
	url="$1"
	output_file="$2"
	ua_header="User-Agent: bifrost/$VERSION"
	accept_header="Accept: application/octet-stream"

	if command -v curl >/dev/null 2>&1; then
		if [[ -n "$GITHUB_TOKEN" ]]; then
			curl -fsSL -H "$ua_header" -H "$accept_header" -H "Authorization: Bearer $GITHUB_TOKEN" "$url" -o "$output_file" 2>/dev/null
		else
			curl -fsSL -H "$ua_header" -H "$accept_header" "$url" -o "$output_file" 2>/dev/null
		fi
		return $?
	fi

	if command -v wget >/dev/null 2>&1; then
		if [[ -n "$GITHUB_TOKEN" ]]; then
			wget -qO "$output_file" --header="$ua_header" --header="$accept_header" --header="Authorization: Bearer $GITHUB_TOKEN" "$url" 2>/dev/null
		else
			wget -qO "$output_file" --header="$ua_header" --header="$accept_header" "$url" 2>/dev/null
		fi
		return $?
	fi

	echo -e "${RED}Download failed:${NC} curl or wget is required."
	return 1
}
calc_sha256(){
	file_path="$1"

	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$file_path" | awk '{print $1}'
		return $?
	fi

	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$file_path" | awk '{print $1}'
		return $?
	fi

	echo -e "${RED}Checksum failed:${NC} sha256sum or shasum is required."
	return 1
}
normalize_version(){
	ver="$1"
	ver="${ver#v}"
	ver="${ver#V}"
	echo "$ver"
}
version_is_newer(){
	current_ver="$(normalize_version "$1")"
	latest_ver="$(normalize_version "$2")"

	if [[ "$current_ver" == "$latest_ver" ]]; then
		return 1
	fi

	highest="$(printf '%s\n%s\n' "$current_ver" "$latest_ver" | sort -V | tail -n1)"
	[[ "$highest" == "$latest_ver" ]]
}
get_latest_release_tag(){
	api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
	response="$(fetch_url "$api_url")" || {
		echo -e "${RED}Update check failed:${NC} unable to fetch latest release for $GITHUB_REPO." >&2
		echo "If the repo is private, set BIFROST_GITHUB_TOKEN (or GITHUB_TOKEN) with repo read access." >&2
		echo "Also verify that a GitHub Release exists for this repository." >&2
		return 1
	}

	tag="$(printf '%s\n' "$response" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
	if [[ -z "$tag" ]]; then
		echo -e "${RED}Update check failed:${NC} unable to parse latest release tag." >&2
		return 1
	fi

	echo "$tag"
}
verify_release_checksum(){
	binary_file="$1"
	checksums_file="$2"

	expected_hash="$(awk -v asset="$RELEASE_ASSET_NAME" '$2 == asset {print $1}' "$checksums_file" | head -n1)"
	if [[ -z "$expected_hash" ]]; then
		echo -e "${RED}Verification failed:${NC} $RELEASE_ASSET_NAME not found in $CHECKSUM_ASSET_NAME."
		return 1
	fi

	actual_hash="$(calc_sha256 "$binary_file")" || return 1
	if [[ "$expected_hash" != "$actual_hash" ]]; then
		echo -e "${RED}Verification failed:${NC} checksum mismatch for downloaded release."
		return 1
	fi

	return 0
}
check_for_update(){
	latest_tag="$(get_latest_release_tag)" || return 1
	latest_ver="$(normalize_version "$latest_tag")"
	current_ver="$(normalize_version "$VERSION")"

	if version_is_newer "$current_ver" "$latest_ver"; then
		echo "Update available: $current_ver -> $latest_ver ($latest_tag)"
		return 0
	fi

	echo "Bifrost is up to date (version $current_ver)."
	return 0
}
install_downloaded_binary(){
	source_file="$1"
	run_as_installer mkdir -p "$INSTALL_DIR" || return 1
	run_as_installer cp "$source_file" "$INSTALL_PATH" || return 1
	run_as_installer chmod 755 "$INSTALL_PATH" || return 1
}
update_from_github(){
	latest_tag="$(get_latest_release_tag)" || return 1
	latest_ver="$(normalize_version "$latest_tag")"
	current_ver="$(normalize_version "$VERSION")"

	if ! version_is_newer "$current_ver" "$latest_ver"; then
		echo "Bifrost is already up to date (version $current_ver)."
		return 0
	fi

	echo "Update available: $current_ver -> $latest_ver"

	tmpdir="$(mktemp -d)"
	binary_tmp="$tmpdir/$RELEASE_ASSET_NAME"
	checksums_tmp="$tmpdir/$CHECKSUM_ASSET_NAME"
	binary_url="https://github.com/$GITHUB_REPO/releases/download/$latest_tag/$RELEASE_ASSET_NAME"
	checksums_url="https://github.com/$GITHUB_REPO/releases/download/$latest_tag/$CHECKSUM_ASSET_NAME"

	download_url_to_file "$binary_url" "$binary_tmp" || {
		echo -e "${RED}Update failed:${NC} unable to download $RELEASE_ASSET_NAME from release $latest_tag."
		rm -rf "$tmpdir"
		return 1
	}

	download_url_to_file "$checksums_url" "$checksums_tmp" || {
		echo -e "${RED}Update failed:${NC} unable to download $CHECKSUM_ASSET_NAME from release $latest_tag."
		rm -rf "$tmpdir"
		return 1
	}

	verify_release_checksum "$binary_tmp" "$checksums_tmp" || {
		rm -rf "$tmpdir"
		return 1
	}

	install_downloaded_binary "$binary_tmp" || {
		rm -rf "$tmpdir"
		return 1
	}

	rm -rf "$tmpdir"
	echo "Updated bifrost to version $latest_ver from GitHub release $latest_tag"
	return 0
}
program_usage(){
	echo "Bifrost v$VERSION"
	echo ""
	echo "Usage:"
	echo "  bifrost                      Interactive menu"
	echo "  bifrost <target>             Connect by index, alias, or server name/prefix"
	echo "  bifrost list                 List servers and aliases"
	echo "  bifrost check-update         Check GitHub for a newer release"
	echo "  bifrost install              Install to $INSTALL_PATH and create profile"
	echo "  bifrost update               Verify and install latest GitHub release"
	echo "  bifrost help                 Show this help"
	echo ""
	echo "Config:"
	echo "  Profile file: $PROFILE_FILE"
	echo "  Override with BIFROST_PROFILE"
}
list_targets(){
	echo "Servers:"
	for (( i=0; i<=LIMIT; i++ )); do
		printf "  %s) %s [%s:%s]\n" "$i" "${SRVNAME[$i]}" "${SRVHOST[$i]}" "${SRVPORT[$i]}"
	done

	echo ""
	echo "Aliases:"
	if (( ${#ALIAS_NAME[@]} == 0 )); then
		echo "  (none)"
		return
	fi

	for (( i=0; i<${#ALIAS_NAME[@]}; i++ )); do
		target="${ALIAS_TARGET[$i]}"
		if (( target >= 0 && target <= LIMIT )); then
			printf "  %s -> %s (%s)\n" "${ALIAS_NAME[$i]}" "$target" "${SRVNAME[$target]}"
		fi
	done
}
install_bifrost(){
	install_binary || exit 1
	write_default_profile

	echo "Installed bifrost to $INSTALL_PATH"
	echo "Profile file: $PROFILE_FILE"

	case ":$PATH:" in
		*":$INSTALL_DIR:"*) ;;
		*)
			echo ""
			echo "Add this to your shell profile if needed:"
			echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
			;;
	esac
}
update_bifrost(){
	update_from_github || exit 1
}
program_header(){
	echo -e "${BLUE}============================================="
echo ""
	echo -e "     Bifrost Server Connection Utility"
echo ""
	echo -e "=============================================${NC}"
	echo ""
}
server_check(){
	tmpdir="$(mktemp -d)"
	declare -a reported

	for (( c=0; c<=$LIMIT; c++ )); do
		reported[$c]=0
		echo -e "$c) ${SRVNAME[$c]} ${YELLOW}(Checking...)${NC}"
	done

	# Save cursor position at the end of the status block so we can repaint lines.
	tput sc

	for (( c=0; c<=$LIMIT; c++ )); do
		(
			checkurl3 "$c" > "$tmpdir/$c"
		) &
	done

	remaining=$TOTAL
	while (( remaining > 0 )); do
		for (( c=0; c<=$LIMIT; c++ )); do
			if (( reported[$c] == 0 )) && [[ -s "$tmpdir/$c" ]]; then
				line="$(<"$tmpdir/$c")"
				tput rc
				tput cuu $((TOTAL - c))
				tput cr
				tput el
				printf "%b\n" "$line"
				reported[$c]=1
				remaining=$((remaining - 1))
			fi
		done

		sleep 0.03
	done

	wait
	tput rc
	rm -rf "$tmpdir"
}
checkurl3(){
	index="$1"
	host="${SRVHOST[$index]}"
	port="${SRVPORT[$index]}"

	if command -v nc >/dev/null 2>&1; then
		nc -z -w 1 "$host" "$port" >/dev/null 2>&1
		reachable=$?
	else
		ping -q -c 1 -W 1 "$host" >/dev/null 2>&1
		reachable=$?
	fi

	if (( reachable == 0 )); then
		serverstatus="$index) ${SRVNAME[$index]} ${GREEN}(Live)${NC}"
	else
		serverstatus="$index) ${SRVNAME[$index]} ${RED}(Offline)${NC}"
	fi

	echo -e "$serverstatus"
}
connect(){
	index="$1"
	host="${SRVHOST[$index]}"
	user="${SRVUSER[$index]}"
	port="${SRVPORT[$index]}"
	name="${SRVNAME[$index]}"

	echo -e "${GREEN}Connecting to $name ...${NC}"
	echo ""
	if [[ -n "$user" ]]; then
		ssh -o ConnectTimeout=5 -p "$port" "$user@$host"
	else
		ssh -o ConnectTimeout=5 -p "$port" "$host"
	fi
}
resolve_target(){
	raw="$1"
	input="${raw,,}"

	# Numeric index mode
	if [[ "$input" =~ ^[0-9]+$ ]]; then
		if (( input >= 0 && input <= LIMIT )); then
			echo "$input"
			return 0
		fi
		return 1
	fi

	for (( i=0; i<${#ALIAS_NAME[@]}; i++ )); do
		alias_name="${ALIAS_NAME[$i],,}"
		target_idx="${ALIAS_TARGET[$i]}"
		if [[ "$input" == "$alias_name" ]] && (( target_idx >= 0 && target_idx <= LIMIT )); then
			echo "$target_idx"
			return 0
		fi
	done

	# Case-insensitive exact or prefix name matching
	match_index=-1
	match_count=0
	for (( i=0; i<=LIMIT; i++ )); do
		candidate="${SRVNAME[$i],,}"
		if [[ "$candidate" == "$input" || "$candidate" == "$input"* ]]; then
			match_index="$i"
			match_count=$((match_count + 1))
		fi
	done

	if (( match_count == 1 )); then
		echo "$match_index"
		return 0
	fi

	return 1
}
quit(){
	echo ""
	echo -e "${YELLOW}============================================="
	echo ""
	echo -e "              Exiting Bifrost" "$(tput el)"
	echo ""
	echo -e "=============================================${NC}"
	echo ""
}
load_profile

if [[ -n "$1" ]]; then
	case "${1,,}" in
		help|-h|--help)
			program_usage
			exit
			;;
		list|--list)
			list_targets
			exit
			;;
		check-update|--check-update)
			check_for_update
			exit
			;;
		install|--install)
			install_bifrost
			exit
			;;
		update|--update)
			update_bifrost
			exit
			;;
	esac
fi

clear
program_header
if [[ -n "$1" ]]; then
	if [[ "${1,,}" == "q" || "${1,,}" == "quit" ]]; then
		quit
		exit
	fi

	target="$(resolve_target "$1")"
	if [[ $? -eq 0 ]]; then
		connect "$target"
		echo "Connecting..."
		exit
	fi

	echo ""
	echo -e "${RED}INVALID TARGET: $1${NC}"
	echo "Try a number (0-$LIMIT), a full/prefix server name, or aliases like 'dvl' and 'dev'."
	exit 1
else
echo -e "There are ${GREEN}$TOTAL${NC} Servers in our Expanded Network"
echo ""
server_check
echo ""
echo "q) Quit"
echo ""
let LINES=$TOTAL+9

while true; do
# clear;
	choice=""
	echo "$(tput cup $LINES 1)"
	echo "$(tput el)"
	read -r -p "Which server (index/name/alias) are you wishing to access? " choice

	if [[ "${choice,,}" == "q" || "${choice,,}" == "quit" ]]; then
		quit
		exit
	fi

	target="$(resolve_target "$choice")"
	if [[ $? -ne 0 ]]; then
		echo ""
		echo -e "${RED}INVALID RESPONSE${NC}"
	else
		clear
		program_header
		connect "$target"
		exit
	fi
done
fi
