# omicron — workspace superproject
#
# The root's ONLY moving parts are the submodule pins (gitlinks) and the
# root docs — see AGENTS.md ("The workspace root is the submodule
# superproject: changes here are only pins (gitlinks), .gitmodules, and
# root docs"). `make pin` is the bump ritual, mechanized: fetch every
# child, fast-forward its local main to origin/main, and land ONE pin-bump
# commit. Pins follow PUSHED main only — a pin is a claim about released
# (or at least pushed) state, never about local WIP.

SUBS := $(shell git config --file .gitmodules --get-regexp '\.path' | awk '{print $$2}')

.PHONY: pin pin-push

pin: ## fast-forward every submodule to origin/main + one pin-bump commit (no push)
	@set -e; \
	moved=""; \
	for sub in $(SUBS); do \
		if [ ! -e "$$sub/.git" ]; then \
			echo "▸ $$sub: skipped (submodule not initialized)"; \
			continue; \
		fi; \
		git -C "$$sub" fetch -q origin; \
		if ! git -C "$$sub" rev-parse --verify -q origin/main >/dev/null; then \
			echo "▸ $$sub: skipped (no origin/main branch)"; \
			continue; \
		fi; \
		git -C "$$sub" checkout -q main; \
		old=$$(git -C "$$sub" rev-parse --short HEAD); \
		if ! git -C "$$sub" pull --ff-only -q origin main; then \
			echo "✗ $$sub: local main DIVERGED from origin/main — resolve by hand, pinning nothing" >&2; \
			exit 1; \
		fi; \
		new=$$(git -C "$$sub" rev-parse --short HEAD); \
		if [ "$$old" != "$$new" ]; then \
			echo "▸ $$sub: $$old → $$new"; \
			moved="$$moved $$sub→$$new"; \
		else \
			echo "▸ $$sub: already at $$new"; \
		fi; \
	done; \
	if [ -z "$$moved" ]; then \
		echo "pins already current — nothing to commit"; \
	else \
		git add $(SUBS); \
		git commit -q -m "chore: bump pins —$$moved"; \
		echo "✓ pin bump committed ($$moved) — now: git push"; \
	fi

pin-push: pin ## pin, then push the bump commit
	git push -q origin main
