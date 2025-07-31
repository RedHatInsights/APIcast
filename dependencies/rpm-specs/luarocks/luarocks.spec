%global commitid fa2736e7c68094710643577b0153dac72ce4bcdc
%global meadalpha %{nil}
%global meadrel %{nil}
%global version_major 3
%global version_minor 11
%global version_micro 1

%define __debug_install_post : > %{_builddir}/%{?buildsubdir}/debugfiles.list
%define debug_package %{nil}

%global luaver  5.1

%global lualibdir %{_libdir}/lua/%{luaver}
%global luapkgdir %{_datadir}/lua/%{luaver}
#global prever rc2

# Use /usr/lib64 as default LUA_LIBDIR
Patch0:         luarocks-3.9.1-dynamic_libdir.patch

%if 0%{?el5}
# For some reason find-debuginfo.sh is still triggered on RHEL 5, despite
# BuildArch being noarch -- the script then fails. Explicitly disable it
%global debug_package %{nil}
%endif

Name:           luarocks
Version:        %{version_major}.%{version_minor}.%{version_micro}
Release:        100%{?dist}
Summary:        A deployment and management system for Lua modules
Source:         luarocks-%{version}-%{release}.tar.gz
BuildRequires:  openresty
Requires:       openresty
Requires:       unzip
Requires:       zip
AutoReq:        no

License:        MIT
%if 0%{?rhel} <= 6
# RHEL 5's rpm requires this field
# RHEL 6's rpmlint warns if it is unspecified
Group:          Development/Tools
%endif
URL:            http://luarocks.org

%if 0%{?el5}
BuildRoot:      %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
%endif


%if 0%{?fedora}
Recommends:     lua-sec
Suggests:       lua-devel
%endif

%description
LuaRocks allows you to install Lua modules as self-contained packages
called "rocks", which also contain version dependency
information. This information is used both during installation, so
that when one rock is requested all rocks it depends on are installed
as well, and at run time, so that when a module is required, the
correct version is loaded. LuaRocks supports both local and remote
repositories, and multiple local rocks trees.


%prep
ls -la %{_sourcedir}
cp -R ../SOURCES/%{name}-%{version}-%{release} %{name}-%{version}-%{release}
%setup -q -T -D -n %{name}-%{version}-%{release}
%patch0 -p1

# sed -i 's|LUAROCKS_ROCKS_SUBDIR=/lib/luarocks/rocks|LUAROCKS_ROCKS_SUBDIR=/%{_lib}/luarocks/rocks|g' configure
# sed -i 's|lib_modules_path = "/lib/lua/"..cfg.lua_version,|lib_modules_path = "/%{_lib}/lua/"..cfg.lua_version,|g' src/luarocks/cfg.lua

%build
./configure \
    --lua-version=%{luaver} \
    --prefix=%{_prefix} \
    --with-lua=/usr/local/openresty/luajit \
    --lua-suffix=jit-2.1.0-beta3 \
    --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1
make


%install
%if 0%{?el5}
rm -rf $RPM_BUILD_ROOT
%endif
make install DESTDIR=$RPM_BUILD_ROOT LUADIR=%{luapkgdir}
# fix symlinks to versioned binaries
#for f in luarocks{,-admin};
#do
#  mv -f $RPM_BUILD_ROOT%{_bindir}/$f{-%{luaver},}
#done

mkdir -p %{buildroot}%{_prefix}/lib64/luarocks/rocks-%{lua_version}

%check
# TODO - find how to run this without having to pre-download entire rocks tree
# ./test/run_tests.sh


%files
%license COPYING*
%doc README.md
%dir %{_sysconfdir}/luarocks
%config(noreplace) %{_sysconfdir}/luarocks/config-%{luaver}.lua
%{_bindir}/luarocks
%{_bindir}/luarocks-admin
%{_prefix}/lib64/luarocks
%{luapkgdir}/luarocks


%changelog
* Wed Nov 27 2024 An Tran <atra@redhat.com> - 3.11.1-100
- Update to luarocks 3.11.1

* Tue Jan 14 2020 Yorgos Saslis <yorgos@redhat.com> - 2.3.0-5
- Uses openresty luajit version (lua 5.1)
- Has build dependency on openresty

* Fri Apr 21 2017 Nick Cross <ncross@redhat.com> - 2.3.0-2
- Add with-lux configure flag.

* Tue Jul  5 2016 Michel Alexandre Salim <salimma@fedoraproject.org> - 2.3.0-1
- Update to 2.3.0
- Use license macro
- On Fedora, add weak dependencies on lua-sec (recommended)
  and lua-devel (suggested)

* Thu Feb 04 2016 Fedora Release Engineering <releng@fedoraproject.org> - 2.2.3-0.3.rc2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_24_Mass_Rebuild

* Thu Dec 10 2015 Tom Callaway <spot@fedoraproject.org> - 2.2.3-0.2.rc2
- update to 2.2.3-rc2
- fix another case of /usr/lib pathing

* Wed Jun 17 2015 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.2.2-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_23_Mass_Rebuild

* Tue Jun  2 2015 Michel Alexandre Salim <salimma@fedoraproject.org> - 2.2.2-1
- Update to 2.2.2
- Add runtime dependencies on unzip and zip (h/t Ignacio Burgueño)

* Thu Jan 15 2015 Tom Callaway <spot@fedoraproject.org> - 2.2.0-2
- rebuild for lua 5.3

* Fri Oct 17 2014 Michel Alexandre Salim <salimma@fedoraproject.org> - 2.2.0-1
- Update to 2.2.0

* Sat Jun 07 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.1.2-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_Mass_Rebuild

* Thu Jan 16 2014 Michel Salim <salimma@fedoraproject.org> - 2.1.2-1
- Update to 2.1.2

* Sat Aug 03 2013 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.0.13-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_20_Mass_Rebuild

* Sun May 12 2013 Tom Callaway <spot@fedoraproject.org> - 2.0.13-2
- rebuild for lua 5.2

* Mon Apr 22 2013 Michel Salim <salimma@fedoraproject.org> - 2.0.13-1
- Update to 2.0.13

* Thu Feb 14 2013 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.0.12-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_19_Mass_Rebuild

* Mon Nov  5 2012 Michel Salim <salimma@fedoraproject.org> - 2.0.12-1.1
- Fix macro problem affecting EPEL builds

* Mon Nov  5 2012 Michel Salim <salimma@fedoraproject.org> - 2.0.12-1
- Update to 2.0.12

* Fri Sep 28 2012 Michel Salim <salimma@fedoraproject.org> - 2.0.11-1
- Update to 2.0.11

* Thu Jul 19 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 2.0.8-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_18_Mass_Rebuild

* Fri May 11 2012 Michel Salim <salimma@fedoraproject.org> - 2.0.8-2
- Add support for RHEL's older lua packaging

* Tue May  8 2012 Michel Salim <salimma@fedoraproject.org> - 2.0.8-1
- Initial package
