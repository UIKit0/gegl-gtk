#!/bin/sh 

# This script does all the magic calls to automake/autoconf and
# friends that are needed to configure a git checkout.  As described in
# the file HACKING you need a couple of extra tools to run this script
# successfully.
#
# If you are compiling from a released tarball you don't need these
# tools and you shouldn't use this script.  Just call ./configure
# directly.

ACLOCAL=${ACLOCAL-aclocal}
AUTOCONF=${AUTOCONF-autoconf}
AUTOHEADER=${AUTOHEADER-autoheader}
AUTOMAKE=${AUTOMAKE-automake}
LIBTOOLIZE=${LIBTOOLIZE-libtoolize}

AUTOCONF_REQUIRED_VERSION=2.54
AUTOMAKE_REQUIRED_VERSION=1.10.0
GLIB_REQUIRED_VERSION=2.8.0
INTLTOOL_REQUIRED_VERSION=0.31
LIBTOOL_REQUIRED_VERSION=1.5

ACLOCAL_FLAGS="-I ./m4 ${ACLOCAL_FLAGS}"

PROJECT="GEGL-GTK"
TEST_TYPE=-f
FILE=gegl-gtk/gegl-gtk.h


srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.
ORIGDIR=`pwd`
cd $srcdir


check_version ()
{
    VERSION_A=$1
    VERSION_B=$2
    PRINT_RESULT=$3

    save_ifs="$IFS"
    IFS=.
    set dummy $VERSION_A 0 0 0
    MAJOR_A=$2
    MINOR_A=$3
    MICRO_A=$4
    set dummy $VERSION_B 0 0 0
    MAJOR_B=$2
    MINOR_B=$3
    MICRO_B=$4
    IFS="$save_ifs"

    version_check_failed=0

    if expr "$MAJOR_A" = "$MAJOR_B" > /dev/null; then
        if expr "$MINOR_A" \> "$MINOR_B" > /dev/null; then
           $PRINT_RESULT && echo "yes (version $VERSION_A)"
        elif expr "$MINOR_A" = "$MINOR_B" > /dev/null; then
            if expr "$MICRO_A" \>= "$MICRO_B" > /dev/null; then
               $PRINT_RESULT && echo "yes (version $VERSION_A)"
            else
                $PRINT_RESULT && echo "Too old (version $VERSION_A)"
                version_check_failed=1
            fi
        else
            $PRINT_RESULT && echo "Too old (version $VERSION_A)"
            version_check_failed=1
        fi
    elif expr "$MAJOR_A" \> "$MAJOR_B" > /dev/null; then
	$PRINT_RESULT && echo "Major version might be too new ($VERSION_A)"
    else
	$PRINT_RESULT && echo "Too old (version $VERSION_A)"
	version_check_failed=1
    fi

    test $version_check_failed -eq 0
}

check_automake_version ()
{
    PROGRAM=$1
    PRINT_RESULT=$2
    VER=`$PROGRAM --version \
         | grep automake | sed "s/.* \([0-9.]*\)[-a-z0-9]*$/\1/"`
    check_version $VER $AUTOMAKE_REQUIRED_VERSION $PRINT_RESULT
}


echo
echo "I am testing that you have the tools required to build the"
echo "$PROJECT project from git. This test is not foolproof,"
echo "so if anything goes wrong, see the file HACKING for more information..."
echo

DIE=0


echo -n "checking for libtool >= $LIBTOOL_REQUIRED_VERSION ... "
if ($LIBTOOLIZE --version) < /dev/null > /dev/null 2>&1; then
   LIBTOOLIZE=$LIBTOOLIZE
elif (glibtoolize --version) < /dev/null > /dev/null 2>&1; then
   LIBTOOLIZE=glibtoolize
else
    echo
    echo "  You must have libtool installed to compile $PROJECT."
    echo "  Install the appropriate package for your distribution,"
    echo "  or get the source tarball at ftp://ftp.gnu.org/pub/gnu/"
    echo
    DIE=1
fi

if test x$LIBTOOLIZE != x; then
    VER=`$LIBTOOLIZE --version \
         | grep libtool | sed "s/.* \([0-9.]*\)[-a-z0-9]*$/\1/"`
    check_version $VER $LIBTOOL_REQUIRED_VERSION true || DIE=1
fi

echo -n "checking for autoconf >= $AUTOCONF_REQUIRED_VERSION ... "
if ($AUTOCONF --version) < /dev/null > /dev/null 2>&1; then
    VER=`$AUTOCONF --version | head -n 1 \
         | grep -iw autoconf | sed "s/.* \([0-9.]*\)[-a-z0-9]*$/\1/"`
    check_version $VER $AUTOCONF_REQUIRED_VERSION true || DIE=1
else
    echo
    echo "  You must have autoconf installed to compile $PROJECT."
    echo "  Download the appropriate package for your distribution,"
    echo "  or get the source tarball at ftp://ftp.gnu.org/pub/gnu/autoconf/"
    echo
    DIE=1;
fi


echo -n "checking for automake >= $AUTOMAKE_REQUIRED_VERSION ... "
if ($AUTOMAKE --version) < /dev/null > /dev/null 2>&1 && \
    check_automake_version $AUTOMAKE false; then
   AUTOMAKE=$AUTOMAKE
   ACLOCAL=$ACLOCAL
elif (automake-1.11 --version) < /dev/null > /dev/null 2>&1 && \
    check_automake_version automake-1.11 false; then
   AUTOMAKE=automake-1.11
   ACLOCAL=aclocal-1.11
elif (automake-1.10 --version) < /dev/null > /dev/null 2>&1 && \
    check_automake_version automake-1.10 false; then
   AUTOMAKE=automake-1.10
   ACLOCAL=aclocal-1.10
else
    echo
    echo "  You must have automake $AUTOMAKE_REQUIRED_VERSION or newer installed to compile $PROJECT."
    echo "  Download the appropriate package for your distribution,"
    echo "  or get the source tarball at ftp://ftp.gnu.org/pub/gnu/automake/"
    echo
    DIE=1
fi

if test x$AUTOMAKE != x; then
    check_automake_version $AUTOMAKE true || DIE=1
fi

if test "$DIE" -eq 1; then
    echo
    echo "Please install/upgrade the missing tools and call me again."
    echo	
    exit 1
fi


test $TEST_TYPE $FILE || {
    echo
    echo "You must run this script in the top-level $PROJECT directory."
    echo
    exit 1
}

echo
echo "I am going to run ./configure with the following arguments:"
echo
echo "  --enable-maintainer-mode --enable-debug $AUTOGEN_CONFIGURE_ARGS $@"
echo

if test -z "$*"; then
    echo "If you wish to pass additional arguments, please specify them "
    echo "on the $0 command line or set the AUTOGEN_CONFIGURE_ARGS "
    echo "environment variable."
    echo
fi


if test -z "$ACLOCAL_FLAGS"; then

    acdir=`$ACLOCAL --print-ac-dir`
    m4list="glib-2.0.m4 pkg.m4" # glib-gettext.m4 intltool.m4

    for file in $m4list
    do
	if [ ! -f "$acdir/$file" ]; then
	    echo
	    echo "WARNING: aclocal's directory is $acdir, but..."
            echo "         no file $acdir/$file"
            echo "         You may see fatal macro warnings below."
            echo "         If these files are installed in /some/dir, set the "
            echo "         ACLOCAL_FLAGS environment variable to \"-I /some/dir\""
            echo "         or install $acdir/$file."
            echo
        fi
    done
fi

rm -rf autom4te.cache

$ACLOCAL $ACLOCAL_FLAGS
RC=$?
if test $RC -ne 0; then
   echo "$ACLOCAL gave errors. Please fix the error conditions and try again."
   exit $RC
fi

$LIBTOOLIZE --force || exit $?

if test x$enable_gtk_doc = xno; then
    echo "WARNING: You have disabled gtk-doc."
    echo "         As a result, you will not be able to generate the API"
    echo "         documentation and 'make dist' will not work."
    echo
else
    gtkdocize --copy --docdir docs --flavour no-tmpl || exit $?
fi

# optionally feature autoheader
($AUTOHEADER --version)  < /dev/null > /dev/null 2>&1 && $AUTOHEADER || exit 1

$AUTOMAKE --add-missing -Wno-portability|| exit $?
$AUTOCONF || exit $?

cd $ORIGDIR

echo
echo "Running ./configure..."
echo

$srcdir/configure --enable-debug --enable-maintainer-mode $AUTOGEN_CONFIGURE_ARGS "$@"
RC=$?
if test $RC -ne 0; then
  echo
  echo "Configure failed or did not finish!"
  exit $RC
fi


echo
echo "Now type 'make' to compile $PROJECT."
