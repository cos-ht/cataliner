# $Id: COScataliner.spec,v 1.6 2014/09/10 17:12:17 jim Exp $
# (C) Nov 2010-Sep 2014 by Jim Klimov, JSC COS&HT
### NOTE/TODO: As an initial opensourcing code drop, this script exposes too
### many internals of the original development environment. Generalize it!
# RPM-build spec file for COScataliner package
# Copy it to the SPECS root of your RPM build area
# See Also: http://www.rpm.org/max-rpm/s1-rpm-build-creating-spec-file.html
### runs ok on buildhost as e.g.:
###   su - jim
###   cd rpm/BUILD
###   rpmbuild -bb COScataliner.spec
#
#
Summary: COS Cataliner framework for proper startup of J2EE appservers
Name: COScataliner
Version: 1.116
Release: 1
License: "(C) 2008-2014 by Jim Klimov, JSC COS&HT, for support of COS projects"
Group: Utilities
#Group: Applications/System
#Source: https://github.com/cos-ht/cataliner-framework
URL: https://github.com/cos-ht/cataliner-framework
Distribution: RHEL/CentOS 5 Linux
Vendor: JSC COS&HT (Center of Open Systems and High Technologies, MIPT, www.cos.ru)
Packager: Jim Klimov <jimklimov@cos.ru>
Prefix: /
BuildRoot: /tmp/rpmbuild-COScataliner
Requires: COSas, COSjisql

%description
These scripts allow for automated startup and shutdown of Tomcat, GlassFish and
JBOSS with various webapps used by us; methods exit only when the webapp has
initialized completely.

# TODO: Make the new git repo layout usable for direct packaging in rules below
%prep
#set
WORKDIR="$RPM_BUILD_DIR/$RPM_PACKAGE_NAME-$RPM_PACKAGE_VERSION-$RPM_PACKAGE_RELEASE"
[ x"$RPM_BUILD_ROOT" != x ] && WORKDIR="$RPM_BUILD_ROOT"
rm -rf "$WORKDIR"
#mkdir -p "$WORKDIR"/opt/COSas/etc
#mkdir -p "$WORKDIR"/etc
#ln -s ../opt/COSas/etc "$WORKDIR"/etc/COSas
mkdir -p "$WORKDIR"/opt/COSas/example && \
    tar c -C /home/jim/pkg/COScataliner*/opt/COSas/example --exclude CVS -f - . | \
    tar x -C "$WORKDIR"/opt/COSas/example -f -
mkdir -p "$WORKDIR"/etc/rc.d/init.d && \
    tar c -C /home/jim/pkg/COScataliner*/etc/init.d --exclude CVS -f - . | \
    tar x -C "$WORKDIR"/etc/rc.d/init.d -f -
#mkdir -p "$WORKDIR"/etc/default && \
#    tar c -C /home/jim/pkg/COScataliner*/default --exclude CVS -f - . | \
#    tar x -C "$WORKDIR"/etc/default -f -
mkdir -p "$WORKDIR"/opt/COSas/pkg && \
    tar c -C /home/jim/pkg/COScataliner* -f - COScataliner.spec | \
    tar x -C "$WORKDIR"/opt/COSas/pkg -f -

%files
%attr(-, bin, bin) %dir /opt/COSas
%attr(700, bin, bin) %dir /opt/COSas/pkg
%attr(-, bin, bin) /opt/COSas/pkg/COScataliner.spec
%attr(755, bin, bin) %dir /opt/COSas/example
%attr(-, bin, bin) /opt/COSas/example/alfresco-example.sh
%attr(-, bin, bin) /opt/COSas/example/check-magnolia-example.sh
%attr(-, bin, bin) /etc/rc.d/init.d/cataliner.sh

%postun
#set -x
### For buggy old RPMs
[ x"$RPM_INSTALL_PREFIX" = x ] && RPM_INSTALL_PREFIX="/"
true

%post
#set -x
### For buggy old RPMs
[ x"$RPM_INSTALL_PREFIX" = x ] && RPM_INSTALL_PREFIX="/"
true
