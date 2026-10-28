PREFIX ?= $(shell brew --prefix 2>/dev/null || echo /usr/local)
BINDIR  = $(PREFIX)/bin
SHAREDIR = $(PREFIX)/share/deskflip

SWIFTC ?= swiftc
SWIFTFLAGS ?= -O

.PHONY: all install uninstall clean

all: deskflip-display

deskflip-display: src/deskflip-display.swift
	$(SWIFTC) $(SWIFTFLAGS) $< -o $@

install: deskflip-display
	install -d $(BINDIR) $(SHAREDIR)
	install -m 755 deskflip $(BINDIR)/deskflip
	install -m 755 deskflip-display $(BINDIR)/deskflip-display
	install -m 644 config.example $(SHAREDIR)/config.example

uninstall:
	rm -f $(BINDIR)/deskflip $(BINDIR)/deskflip-display
	rm -rf $(SHAREDIR)

clean:
	rm -f deskflip-display
