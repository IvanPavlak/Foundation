# The commands of the module manifests and the Unix/config files each one reads - the
# classification behind the configuration guides (docs/foundation/guides/README.md). Load after
# helpers; shared by guides.bats.

# The shared libraries every command loads; the files they read configure everything, not one
# command, so they do not make a command configurable.
GUIDES_SHARED_LIBS='^(config|apps|logfile|log|backup|spinner|drivers/.*)$'

# Every command line of every manifest: MODULE<TAB>NAME<TAB>EXECUTABLE<TAB>GUIDE, the guide path
# relative to docs/foundation/guides (Custom area: custom/<module>/).
guides_commands() {
	local manifest dir module folder kind name
	for manifest in "$UNIX_DIR"/modules/*/module.conf "$UNIX_DIR"/modules/Custom/*/module.conf; do
		[ -f "$manifest" ] || continue
		dir=$(dirname "$manifest")
		module=${dir#"$UNIX_DIR"/modules/}
		folder=$(printf '%s' "$module" | tr '[:upper:]' '[:lower:]')
		while read -r kind name _; do
			[ "$kind" = command ] || continue
			printf '%s\t%s\t%s\t%s\n' "$module" "$name" "$dir/bin/$name" "$folder/$name.md"
		done <"$manifest"
	done
}

# The Unix/config files a command reads, one per line: `conf_path NAME.conf` in its executable and
# in the libraries any of its foundation_load calls names (a step may load one late), the shared
# ones left out.
# Usage: command_config_files EXECUTABLE
command_config_files() {
	local exe=$1 lib
	{
		grep -oE 'conf_path [a-z][a-z-]*\.conf' "$exe" | awk '{ print $2 }'
		for lib in $(grep -oE 'foundation_load( [a-z/]+)+' "$exe" | cut -d' ' -f2- | tr ' ' '\n' | sort -u); do
			[[ $lib =~ $GUIDES_SHARED_LIBS ]] && continue
			[ -f "$UNIX_DIR/lib/$lib.sh" ] || continue
			grep -oE 'conf_path [a-z][a-z-]*\.conf' "$UNIX_DIR/lib/$lib.sh" 2>/dev/null | awk '{ print $2 }'
		done
	} | sort -u
}
