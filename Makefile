.PHONY: init generate publish
MSG ?= $(shell git log --oneline --format=%B -n 1 HEAD)

init:
	git worktree add -B gh-pages public origin/gh-pages

generate: # Call with MSG='Add new post' to change the commit message used
	git stash -a
	rm -rf public/*
	hugo
	cp CNAME public
	git -C public add --all
	git -C public commit -m "$(MSG)"
	git stash pop

publish:
	git -C public push
