# Copyright 2020 Hewlett Packard Enterprise Development LP
%define namespace dracut
# disable compressing files
%define __os_install_post %{nil}
%define intranamespace_name metal-luksetcd
%define x_y_z %(cat .version)
%define release_extra %(if [ -e "%{_sourcedir}/_release_extra" ] ; then cat "%{_sourcedir}/_release_extra"; else echo ""; fi)
%define source_name %{name}

################################################################################
# Primary package definition #
################################################################################

Name: %{namespace}-%{intranamespace_name}
Packager: <rustydb@hpe.com>
Release: %(echo ${BUILD_METADATA})
Vendor: Cray HPE
Version: %{x_y_z}
Source: %{source_name}.tar.bz2
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}
Group: System/Management
License: MIT License
Summary: Dracut module for setting up an encrypted disk with LVMs for etcd (or any secure purpose).

Requires: rpm
Requires: coreutils
Requires: dracut
Requires: dracut-metal-mdsquash

%define dracut_modules /usr/lib/dracut/modules.d
%define url_dracut_doc /usr/share/doc/metal-dracut/luksetcd/

%description

%prep

%setup

%build

%install
%{__mkdir_p} %{buildroot}%{dracut_modules}/98metalluksetcd
%{__mkdir_p} %{buildroot}%{url_dracut_doc}
%{__install} -m 0755 metal-luksetcd-disk.sh module-setup.sh metal-update-keystore.sh parse-metal-luksetcd.sh metal-luksetcd-lib.sh metal-luksetcd-genrules.sh %{buildroot}%{dracut_modules}/98metalluksetcd
%{__install} -m 0644 README.md %{buildroot}%{url_dracut_doc}

%files
%defattr(0755, root, root)
%license LICENSE
%dir %{dracut_modules}/98metalluksetcd
%{dracut_modules}/98metalluksetcd/*.sh
%dir %{url_dracut_doc}
%attr(644, root, root) %{url_dracut_doc}/README.md

%pre

%post

%preun

%changelog
