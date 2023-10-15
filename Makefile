fmt:
	echo "===> Format"
	stylua lua/

test:
	echo "===> Test"
	nvim --headless --clean -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/vimed/ {minimal_init = 'tests/minimal_init.vim'}"
	rm -rf tests/vimed/workdir

setup-ci:
	echo "===> Set Up CI"
	nvim --headless --clean -u tests/ci.vim -c "q"
