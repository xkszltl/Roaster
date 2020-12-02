export SHELL = /bin/bash

export MKDIR = mkdir -p
export RM = rm -rf

.PHONY: all
all: arch.pdf arch.svg

arch.pdf: %.pdf: %.dot
	dot -Kdot -Tpdf -o $@ $<

arch.svg: %.svg: %.dot
	dot -Kdot -Tsvg -o $@ $<

.PHONY: clean
clean:
	@$(RM) arch.{pdf,svg}
