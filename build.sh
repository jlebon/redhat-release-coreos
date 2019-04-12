#!/usr/bin/bash
set -xeuo pipefail
srcdir=$(cd $(dirname $0) && pwd)
rm fs fs.tmp -rf
mkdir -p fs.tmp
cd fs.tmp

base_release_version=8
full_release_version=4.1

mkdir -m 0755 -p usr/lib
# create os-release
cat << EOF > usr/lib/os-release
NAME="Red Hat Enterprise Linux CoreOS"
VERSION="${full_release_version}"
VERSION_ID="${full_release_version}"
PRETTY_NAME="Red Hat Enterprise Linux CoreOS ${full_release_version} (Ootpa)"
ID="rhcos"
ID_LIKE="rhel fedora"
ANSI_COLOR="0;31"
HOME_URL="https://www.redhat.com/"
BUG_REPORT_URL="https://bugzilla.redhat.com/"

REDHAT_BUGZILLA_PRODUCT="OpenShift Container Platform"
REDHAT_BUGZILLA_PRODUCT_VERSION="${full_release_version}"
REDHAT_SUPPORT_PRODUCT="OpenShift Container Platform"
REDHAT_SUPPORT_PRODUCT_VERSION="${full_release_version}"
EOF
mkdir -m 0755 -p etc
ln -s ../usr/lib/os-release etc/os-release
# Sadly grub2 still reads this
ln -s ../usr/lib/os-release etc/system-release

# create /etc/issue, /etc/issue.net, and /etc/issue.d
cat > usr/lib/issue <<'EOF'
\S \S{VERSION_ID}
EOF
ln -sr usr/lib/issue etc/issue
ln -sr usr/lib/issue etc/issue.net
mkdir -p -m 755 etc/issue.d

# combine GPG keys
mkdir -p -m 755 etc/pki/rpm-gpg
cat ${srcdir}/RPM-GPG-KEY-redhat-release-2 ${srcdir}/RPM-GPG-KEY-redhat-auxiliary > etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
cat ${srcdir}/RPM-GPG-KEY-redhat-beta-2 ${srcdir}/RPM-GPG-KEY-redhat-legacy-beta > etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta

# copy GPG keys into the libostree keyring
mkdir -p -m 755 usr/share/ostree/trusted.gpg.d
for file in etc/pki/rpm-gpg/RPM-GPG-KEY* ; do
    gpg --dearmor < $file > usr/share/ostree/trusted.gpg.d/$(basename ${file}).gpg
done

# write out redhat-release
echo "Red Hat Enterprise Linux CoreOS release ${full_release_version}" > usr/lib/redhat-release
ln -sf ../usr/lib/redhat-release etc/system-release
ln -sf ../usr/lib/redhat-release etc/redhat-release

# setup default PATH; pathmunge() will add the supplied value to the PATH
# if it does not already exist
# https://github.com/openshift/os/issues/191
mkdir -p -m 755 etc/profile.d
cat > etc/profile.d/path.sh <<EOF
pathmunge /bin
pathmunge /sbin
pathmunge /usr/bin
pathmunge /usr/sbin
pathmunge /usr/local/bin
pathmunge /usr/local/sbin
EOF

# set up the dist tag macros
install -d -m 755 etc/rpm
cat >> etc/rpm/macros.dist << EOF
# dist macros.

%rhel ${base_release_version}
%dist .el8
%el${base_release_version} 1
EOF

# use unbranded datadir
mkdir -p -m 755 usr/share/redhat-release
install -m 644 ${srcdir}/EULA usr/share/redhat-release

# use unbranded docdir
mkdir -p -m 755 usr/share/doc/redhat-release
install -m 644 ${srcdir}/GPL usr/share/doc/redhat-release

# copy systemd presets
mkdir -p usr/lib/systemd/system-preset/
for x in ${srcdir}/*.preset; do install -m 0644 ${x} usr/lib/systemd/system-preset/; done

# copy systemd units
mkdir -p usr/lib/systemd/system/
for x in ${srcdir}/*.service; do install -m 0644 ${x} usr/lib/systemd/system/; done

# https://bugzilla.redhat.com/show_bug.cgi?id=1204194
mkdir -p etc/systemd/system
ln -s /dev/null etc/systemd/system/brandbot.path

cd ..
mv fs.tmp fs
