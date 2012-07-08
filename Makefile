CC=gcc

# if user has not defined the apxs path, try to set
# it here
ifeq ($(APXS_PATH),)
  APXS_PATH := $(shell which apxs)
endif

# check again, abort on error
ifeq ($(APXS_PATH),)
  $(error Cannot find Apache utility program 'apxs')
endif

MY_LDFLAGS=-lcurl -lyajl

# Note that gcc flags are passed through apxs, so preface with -Wc
MY_CFLAGS=-Wc,-I. -Wc,-Wall

# note apsx adds "_module" to the name
MODULE_NAME := auth_browserid

.SUFFIXES: .c .o .la
.c.la:
	$(APXS_PATH) $(MY_LDFLAGS) $(MY_CFLAGS) -c $< -n $(MODULE_NAME)
.c.o:
	$(CC) -c $<

all:  mod_auth_browserid.la 

install: mod_auth_browserid.la 
	@echo "-"$*"-" "-"$?"-" "-"$%"-" "-"$@"-" "-"$<"-"
	$(APXS_PATH) -i -n $(MODULE_NAME) -a $?

clean:
	-rm -f *.o *.lo *.la *.slo 
	-rm -rf .libs

