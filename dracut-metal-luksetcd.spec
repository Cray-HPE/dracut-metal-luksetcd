#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
Name: %(echo $NAME)
Packager: <doomslayer@hpe.com>
Release: 1
Vendor: Hewlett Packard Enterprise Development LP
Version: %(echo $VERSION)
Source: %{name}-%{version}.tar.bz2
BuildArch: noarch
Group: System/Management
License: MIT License
Summary: Dracut module for setting up an encrypted disk with LVMs for etcd (or any secure purpose).
Provides: metal-luksetcd

Requires: coreutils
Requires: cryptsetup
Requires: dracut
Requires: dracut-metal-mdsquash
Requires: lvm2
Requires: parted
Requires: util-linux
Requires: util-linux-systemd
Requires: xfsprogs


%define dracut_modules /usr/lib/dracut/modules.d
%define module_name 93metalluksetcd
Provides: %{module_name}
%define url_dracut_doc /usr/share/doc/metal/%{module_name}/

%description

%prep

%setup -q

%build

%install
%{__mkdir_p} %{buildroot}%{url_dracut_doc}
%{__mkdir_p} %{buildroot}%{dracut_modules}/%{module_name}
cp -pvrR ./%{module_name}/* %{buildroot}%{dracut_modules}/%{module_name} | awk '{print $3}' | sed "s/'//g" | sed "s|$RPM_BUILD_ROOT||g" | tee -a INSTALLED_FILES
%{__install} -m 0644 README.md %{buildroot}%{url_dracut_doc}

%files -f INSTALLED_FILES
%defattr(0755, root, root)
%license LICENSE
%dir %{dracut_modules}/%{module_name}
%dir %{url_dracut_doc}
%attr(644, root, root) %{url_dracut_doc}/README.md

%pre

%post

%preun

%posttrans
mkinitrd -B

%changelog
