#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Prevent a clash between some Perl and libstdc++ macros. */
#undef do_open
#undef do_close

#include <store-api.hh>
#include <globals.hh>
#include <misc.hh>
#include <util.hh>


using namespace nix;


void doInit() 
{
    if (!store) {
        nixStore = canonPath(getEnv("NIX_STORE_DIR", getEnv("NIX_STORE", "/nix/store")));
        nixStateDir = canonPath(getEnv("NIX_STATE_DIR", "/nix/var/nix"));
        nixDBPath = getEnv("NIX_DB_DIR", nixStateDir + "/db");
        try {
            store = openStore();
        } catch (Error & e) {
            croak(e.what());
        }
    }
}


MODULE = Nix::Store PACKAGE = Nix::Store
PROTOTYPES: ENABLE


void init()
    CODE:
        doInit();


int isValidPath(path)
        char * path
    CODE:
        try {
            doInit();
            RETVAL = store->isValidPath(path);
        } catch (Error & e) {
            croak(e.what());
        }
    OUTPUT:
        RETVAL


SV * queryReferences(path)
        char * path
    PPCODE:
        try {
            doInit();
            PathSet paths;
            store->queryReferences(path, paths);
            for (PathSet::iterator i = paths.begin(); i != paths.end(); ++i)
                XPUSHs(sv_2mortal(newSVpv(i->c_str(), 0)));
        } catch (Error & e) {
            croak(e.what());
        }


SV * queryPathHash(path)
        char * path
    PPCODE:
        try {
            doInit();
            Hash hash = store->queryPathHash(path);
            string s = "sha256:" + printHash(hash);
            XPUSHs(sv_2mortal(newSVpv(s.c_str(), 0)));
        } catch (Error & e) {
            croak(e.what());
        }


SV * queryDeriver(path)
        char * path
    PPCODE:
        try {
            doInit();
            Path deriver = store->queryDeriver(path);
            if (deriver == "") XSRETURN_UNDEF;
            XPUSHs(sv_2mortal(newSVpv(deriver.c_str(), 0)));
        } catch (Error & e) {
            croak(e.what());
        }


SV * queryPathInfo(path)
        char * path
    PPCODE:
        try {
            doInit();
            ValidPathInfo info = store->queryPathInfo(path);
            if (info.deriver == "")
                XPUSHs(&PL_sv_undef);
            else
                XPUSHs(sv_2mortal(newSVpv(info.deriver.c_str(), 0)));
            string s = "sha256:" + printHash(info.hash);
            XPUSHs(sv_2mortal(newSVpv(s.c_str(), 0)));
            mXPUSHi(info.registrationTime);
            mXPUSHi(info.narSize);
            AV * arr = newAV();
            for (PathSet::iterator i = info.references.begin(); i != info.references.end(); ++i)
                av_push(arr, newSVpv(i->c_str(), 0));
            XPUSHs(sv_2mortal(newRV((SV *) arr)));
        } catch (Error & e) {
            croak(e.what());
        }


SV * computeFSClosure(int flipDirection, int includeOutputs, ...)
    PPCODE:
        try {
            doInit();
            PathSet paths;
            for (int n = 2; n < items; ++n)
                computeFSClosure(*store, SvPV_nolen(ST(n)), paths, flipDirection, includeOutputs);
            for (PathSet::iterator i = paths.begin(); i != paths.end(); ++i)
                XPUSHs(sv_2mortal(newSVpv(i->c_str(), 0)));
        } catch (Error & e) {
            croak(e.what());
        }