#!/usr/bin/env bats
# Invoke-GoogleTranslate (translate) against a curl stand-in: the translation is printed, 429 and other errors are readable.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Invoke-GoogleTranslate
}

@test "prints the joined translation for the configured target language" {
	stub_tool curl 'printf "%s\n200" "[[[\"Good \",\"Dobro \"],[\"morning\",\"jutro\"]]]"'
	run "${BASH:-bash}" "$cmd" dobro jutro
	[ "$status" -eq 0 ]
	[[ $output == *"=> Good morning"* ]]
	grep -q 'tl=en' "$BATS_TEST_TMPDIR/tool.log"
}

@test "HTTP 429 and an unknown language give a readable failure" {
	stub_tool curl 'printf "\n429"'
	run "${BASH:-bash}" "$cmd" hello
	[ "$status" -ne 0 ]
	[[ $output == *"rate-limiting"* ]]
	run "${BASH:-bash}" "$cmd" --output-language Klingonese hello
	[ "$status" -ne 0 ]
	[[ $output == *"Unsupported output language"* ]]
}

@test "Chinese is a target language (zh-CN), by name or code" {
	stub_tool curl 'printf "%s\n200" "[[[\"ni hao\",\"hello\"]]]"'
	run "${BASH:-bash}" "$cmd" --output-language Chinese hello
	[ "$status" -eq 0 ]
	[[ $output == *"[Chinese] => ni hao"* ]]
	grep -q 'tl=zh-CN' "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --output-language zh-cn hello
	[ "$status" -eq 0 ]
}

@test "Automatic, Auto and Detect as the input language detect it; a named one is sent" {
	stub_tool curl 'printf "%s\n200" "[[[\"hello\",\"bok\"]]]"'
	for word in Automatic auto DETECT; do
		: >"$BATS_TEST_TMPDIR/tool.log"
		run "${BASH:-bash}" "$cmd" --input-language "$word" bok
		[ "$status" -eq 0 ]
		grep -q 'sl=auto' "$BATS_TEST_TMPDIR/tool.log"
	done
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --input-language Croatian bok
	[ "$status" -eq 0 ]
	grep -q 'sl=hr' "$BATS_TEST_TMPDIR/tool.log"
}

@test "an unsupported language lists the supported names and sends nothing" {
	stub_tool curl 'printf "%s\n200" "[[[\"x\",\"y\"]]]"'
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --input-language Klingonese hello
	[ "$status" -ne 0 ]
	[[ $output == *"Unsupported input language: [Klingonese]"* ]]
	[[ $output == *"  - Chinese"* ]]
	[[ $output == *"  - Croatian"* ]]
	[ ! -s "$BATS_TEST_TMPDIR/tool.log" ]
}
