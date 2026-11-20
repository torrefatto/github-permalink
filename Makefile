VIM ?= vim

.PHONY: test
test:
	@set -eu; \
	repo="$$(mktemp -d /tmp/github-permalink-test.XXXXXX)"; \
	trap 'rm -rf "$$repo" "$$(dirname "$$repo")/outside.txt"' EXIT; \
	git -C "$$repo" init -q; \
	git -C "$$repo" config user.email test@example.com; \
	git -C "$$repo" config user.name Test; \
	mkdir -p "$$repo/dir"; \
	printf 'one\ntwo\nthree\nfour\nfive\n' > "$$repo/dir/a b.txt"; \
	printf 'one\ntwo\n' > "$$repo/dir/café.txt"; \
	printf 'committed\n' > "$$repo/dirty.txt"; \
	git -C "$$repo" add .; \
	git -C "$$repo" commit --no-verify -qm initial; \
	git -C "$$repo" remote add origin git@github.com:example/project.git; \
	printf 'working tree changed\n' > "$$repo/dirty.txt"; \
	printf 'untracked\n' > "$$repo/untracked.txt"; \
	printf 'outside\n' > "$$(dirname "$$repo")/outside.txt"; \
	GITHUB_PERMALINK_TEST_REPO="$$repo" $(VIM) -Nu NONE -n -i NONE -es \
		+'set runtimepath^=$(CURDIR)' \
		+'runtime plugin/github_permalink.vim' \
		+'let mapleader="\\"' \
		+'nmap <Leader>gy <Plug>(github-permalink)' \
		+'xmap <Leader>gy <Plug>(github-permalink)' \
		-S "$(CURDIR)/test/github_permalink.vim"; \
	if [ -f "$$repo/failures" ]; then cat "$$repo/failures"; exit 1; fi; \
	printf 'github permalink tests passed\n'
