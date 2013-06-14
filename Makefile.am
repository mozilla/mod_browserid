AUTOMAKE_OPTIONS=foreign
ACLOCAL_AMFLAGS = -I build

module_LTLIBRARIES = mod_auth_browserid.la
moduledir = $(shell $(APXS) -q LIBEXECDIR)

EXTRA_DIST=t README TODO LICENSE build/mod_auth_browserid.spec build/test.pl .indent.pro

APR_CONFIG = $(shell $(APXS) -q APR_CONFIG)
APU_CONFIG = $(shell $(APXS) -q APU_CONFIG)
APR_CFLAGS = $(shell $(APR_CONFIG) --cflags --cppflags --includes) -Wall -Werror
APU_CFLAGS = $(shell $(APU_CONFIG) --includes)
HTTPD_CFLAGS = $(shell $(APXS) -q CFLAGS) -I $(shell $(APXS) -q INCLUDEDIR)

#LIBTOOL = $(shell $(APR_CONFIG) --apr-libtool)

AM_CFLAGS = $(HTTPD_CFLAGS) $(APR_CFLAGS) $(APU_CFLAGS) $(LIBCURL) -L/usr/local/lib -lyajl  -Wl,-rpath=/usr/local/lib

mod_auth_browserid_la_SOURCES = mod_auth_browserid.c 
mod_auth_browserid_la_LDFLAGS = -module -avoid-version

check: test

test: all t/TEST
	$(PERL) t/TEST

t/TEST: build/test.pl
	$(PERL) build/test.pl -apxs $(APXS)

dist-hook:
	rm -rf `find $(distdir)/t -name .svn`

rpm: dist
	rpmbuild -ta $(DIST_ARCHIVES)

indent:
	indent -i4 -npsl -di0 -br -nce -d0 -cli0 -npcs -nfc1 -nut *.c $(SOURCES)
