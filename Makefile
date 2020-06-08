mkfile_path := $(realpath $(lastword $(MAKEFILE_LIST)))

.PHONY: pip
pip:
	pip install --upgrade pip pynvim pip-tools

.PHONY: setup-langservers
setup-langservers:
	cd $(dir $(mkfile_path)) && ./langservers/setup.sh

.PHONY: update-spell
update-spell:
	cd $(dir $(mkfile_path))/spell && \
		curl -sLO http://ftp.vim.org/vim/runtime/spell/en.utf-8.spl && \
		curl -sLO http://ftp.vim.org/vim/runtime/spell/en.utf-8.spl && \
		curl -sLO http://ftp.vim.org/vim/runtime/spell/pt.utf-8.spl

.PHONY: plug-setup
plug-setup: install-vim-plug
	if command -v nvim &>/dev/null; then nvim --headless +'PlugInstall|qa' +cq; fi

.PHONY: install-vim-plug
install-vim-plug:
	cp vim-plug/plug.vim autoload/plug.vim

.PHONY: bootstrap
bootstrap: submodules pip setup-langservers plug-setup

.PHONY: submodules
submodules:
	git submodule update --init --recursive

.PHONY: clean
clean:
	git clean -dfx

.PHONY: rebootstrap
rebootstrap: clean bootstrap

.PHONY: shellcheck
shellcheck:
	shellcheck bin/vim-* langservers/setup.sh
