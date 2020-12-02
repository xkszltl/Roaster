export SHELL = /bin/bash

export MKDIR = mkdir -p
export RM = rm -rf

.PHONY: all
all: arch.pdf

arch.pdf: %.pdf: %.dot
	dot -Kdot -Tpdf -o $@ $<

.PHONY: clean
clean:
	@$(RM) arch.pdf
