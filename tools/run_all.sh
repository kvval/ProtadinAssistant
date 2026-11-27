#!/usr/bin/env bash
# Run every local check; exit non-zero if anything fails.
# Used locally and by .github/workflows/release.yml before packaging.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { # name, command, expected text (optional)
	local name="$1" cmd="$2" want="${3:-}" out
	out=$(eval "$cmd" 2>&1); local rc=$?
	if [ $rc -ne 0 ] || grep -qE "^lua5\.1:|FAIL|problems$" <<<"$out" || { [ -n "$want" ] && ! grep -qF -- "$want" <<<"$out"; }; then
		echo "FAIL  $name"; echo "$out" | tail -15 | sed 's/^/      /'; fail=1
	else
		echo "ok    $name"
	fi
}

for f in Modules/*.lua Locales/*.lua; do check "syntax $f" "luac5.1 -p '$f' && rm -f luac.out"; done
check "harness enUS" "lua5.1 tools/harness.lua . enUS" "HARNESS OK"
check "harness ruRU" "lua5.1 tools/harness.lua . ruRU" "HARNESS OK"
keys=$(mktemp)
grep -h -o 'L\["[^"]*"\]' Modules/*.lua | sed -E 's/^L\["(.*)"\]$/\1/' | sort -u > "$keys"
check "locales" "lua5.1 tools/loccheck2.lua . '$keys'" "all OK"
rm -f "$keys"
check "learned priority" "lua5.1 tools/learn_test.lua . | awk -F'\t' '/^learned:/{l=\$2} /^taste:/{t=\$2} END{print (l==t ? \"order ok\" : \"order differs\")}'" "order ok"
check "situational spells" "lua5.1 tools/situational_test.lua ." "Exorcism kept 4th:	true"
check "auto adapt" "lua5.1 tools/autoadapt_test.lua ." "swaps A B C"
check "decay" "lua5.1 tools/decay_test.lua ." "50.0"
check "priority list" "lua5.1 tools/list_test.lua ." "add Holy Shield"
check "range" "lua5.1 tools/range_test.lua ." "Exorcism      InRange=false expected=false OK"
check "mana" "lua5.1 tools/mana_test.lua . | grep -E 'cost 400 > mana 300 +-> false'"
check "restricted auras" "lua5.1 tools/restrict_test.lua ." "api throws:"
check "grid snapping" "lua5.1 tools/snap_test.lua ." "dx 40.0, dy -200.0"
check "loading screens" "lua5.1 tools/loading_test.lua . enUS" "LOADING TEST DONE"
check "auto food/bag" "lua5.1 tools/autoslot_test.lua . enUS" "AUTOSLOT TEST DONE"
check "food pick" "lua5.1 tools/food_test.lua . enUS" "FOOD TEST DONE"
check "hand-over" "lua5.1 tools/handover_test.lua . enUS" "HANDOVER TEST DONE"
check "seal" "lua5.1 tools/seal_test.lua . enUS" "SEAL TEST DONE"
check "chat links" "lua5.1 tools/links_test.lua . enUS" "LINKS TEST DONE"
check "idle / pre-pull" "lua5.1 tools/idle_prepull_test.lua . enUS" "IDLE PREPULL TEST DONE"
check "stored by spell ID" "lua5.1 tools/storage_test.lua . enUS" "loaded wins:	Правосудие	->	Щит небес	12.5"
check "talents forget cooldowns, login ignored" "lua5.1 tools/talent_test.lua . enUS" "at login:	8"
check "talent change clears learned" "lua5.1 tools/talent_test.lua . enUS" "after respec:	nil"
check "cooldowns asked only after events" "lua5.1 tools/talent_test.lua . enUS" "queries in 10 s without events:	5"
check "cooldown from tooltip (sec)" "lua5.1 tools/tipcd_test.lua . enUS" "en sec:	8"
check "cooldown from tooltip (min)" "lua5.1 tools/tipcd_test.lua . enUS" "en min:	3600"
check "cooldown from tooltip (decimal)" "lua5.1 tools/tipcd_test.lua . enUS" "en decimal:	1.5"

[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
