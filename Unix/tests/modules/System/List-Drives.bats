#!/usr/bin/env bats
# List-Drives against df and uname stand-ins: the startup volume and /Volumes entries (spaces kept)
# are listed with size, use and free space; system volumes and Recovery are left out, on the BSD
# (macOS) and the GNU df layout alike.

load ../../helpers

setup() {
	setup_foundation
	# BSD df -H has inode columns (mount point from field 9); GNU df -H -P has none (field 6).
	stub_tool df 'case " $* " in
	*" -P "*) cat <<EOF
Filesystem     Size  Used Avail Capacity Mounted on
/dev/sda1      494G   11G  180G       6% /
tmpfs          8.0G     0  8.0G       0% /run
/dev/sdb1      2.0T  1.0T  1.0T      50% /Volumes/My Disk
EOF
	;;
	*) cat <<EOF
Filesystem       Size   Used  Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1s1   494G    11G   180G     6%    426k  1.8G    0%   /
/dev/disk3s6     494G   2.1G   180G     2%       2  1.8G    0%   /System/Volumes/VM
/dev/disk5s1     2.0T   1.0T   1.0T    50%    100k  9.0G    0%   /Volumes/My Disk
/dev/disk4s1     5.0G   1.0G   4.0G    20%      10  1.0G    0%   /Volumes/Recovery
EOF
	;;
esac'
	stub_tool uname 'echo Darwin'
	[ "$(command -v df)" = "$BATS_TEST_TMPDIR/tools/df" ]
	[ "$(command -v uname)" = "$BATS_TEST_TMPDIR/tools/uname" ]
	cmd=$UNIX_DIR/modules/System/bin/List-Drives
}

listed() {
	printf '%s\n' "$output" | grep -qE "$1"
}

@test "macOS: the startup volume and /Volumes are listed, system volumes and Recovery are not" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	listed '^  / +494G +11G +180G +6%$'
	listed '^  /Volumes/My Disk +2\.0T +1\.0T +1\.0T +50%$'
	! listed 'System/Volumes' || false
	! listed 'Recovery' || false
	grep -qx 'df -H' "$BATS_TEST_TMPDIR/tool.log"
}

@test "Linux: GNU df -P is read from field 6" {
	stub_tool uname 'echo Linux'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	listed '^  / +494G +11G +180G +6%$'
	listed '^  /Volumes/My Disk +2\.0T'
	! listed '/run' || false
}
