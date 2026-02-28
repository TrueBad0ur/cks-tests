# Image Security - Trivy Analysis

## Question 1
Scan nginx:1.19.0 for vulnerabilities:
- How many Critical, High, Medium, Low vulnerabilities?
❯ /tmp/trivy image --scanners vuln nginx:1.19.0 --severity CRITICAL -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u | wc     
36

❯ /tmp/trivy image --scanners vuln nginx:1.19.0 --severity HIGH -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u | wc
126

❯ /tmp/trivy image --scanners vuln nginx:1.19.0 --severity MEDIUM -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u | wc
133

❯ /tmp/trivy image --scanners vuln nginx:1.19.0 --severity LOW -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u | wc
28

## Question 2
Scan nginx:1.25 and compare:
- How many vulnerabilities does it have?
- Show the diff between Critical vulnerabilities in 1.19.0 and 1.25.
❯ /tmp/trivy image --scanners vuln nginx:1.25 -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u | wc 
225

❯ /tmp/trivy image --scanners vuln nginx:1.19.0 --severity CRITICAL -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u > result1
❯ /tmp/trivy image --scanners vuln nginx:1.25 --severity CRITICAL -q --format json | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u > result2
❯ diff result1 result2
result1 --- Text
 1 CVE-2018-25009              . 
 2 CVE-2018-25010              . 
 3 CVE-2018-25011              . 
 4 CVE-2018-25012              . 
 5 CVE-2018-25013              . 
 6 CVE-2018-25014              . 
 7 CVE-2019-20367              . 
 8 CVE-2019-8457               . 
 9 CVE-2020-15999              . 
10 CVE-2020-36328              . 
11 CVE-2020-36329              . 
12 CVE-2020-36330              . 
13 CVE-2020-36331              . 
14 CVE-2021-20231              . 
15 CVE-2021-20232              . 
16 CVE-2021-31535              . 
17 CVE-2021-33574              . 
18 CVE-2021-3520               . 
19 CVE-2021-35942              . 
20 CVE-2021-3711               . 
21 CVE-2021-46848              . 
22 CVE-2022-1664               . 
23 CVE-2022-22822              . 
24 CVE-2022-22823              . 
25 CVE-2022-22824              . 
26 CVE-2022-23218              . 
27 CVE-2022-23219              . 
28 CVE-2022-23852              . 
29 CVE-2022-25235              . 
30 CVE-2022-25236              . 
31 CVE-2022-25315              . 
32 CVE-2022-27404              . 
33 CVE-2022-29155              . 
34 CVE-2022-32221              . 
35 CVE-2022-37434              . 
36 CVE-2023-45853              1 CVE-2023-45853
                               2 CVE-2023-6879
                               3 CVE-2024-37371
                               4 CVE-2024-45491
                               5 CVE-2024-45492
                               6 CVE-2024-5171
                               7 CVE-2024-56171
                               8 CVE-2025-0838
                               9 CVE-2025-15467
                              10 CVE-2025-48174
                              11 CVE-2025-49794
                              12 CVE-2025-49796

## Question 3
Scan the Dockerfile in configs/Dockerfile using Trivy config:
- What security issues did you find?
❯ /tmp/trivy config ./Dockerfile
AVD-DS-0002 (HIGH): Last USER command in Dockerfile should not be 'root'
AVD-DS-0026 (LOW): Add HEALTHCHECK instruction in your Dockerfile
AVD-DS-0029 (HIGH): '--no-install-recommends' flag is missed: 'apt-get update && apt-get install -y python3     && useradd -m appuser'

## Question 4
Generate an SBOM for nginx:1.25 in SPDX format:
- List the packages found in the image.
❯ /tmp/trivy image --format cyclonedx --output result.json nginx:1.25
❯ jq -r '.components[] | "\(.name)@\(.version)"' result.json
debian@12.5
adduser@3.134
apt@2.6.1
base-files@12.4+deb12u5
base-passwd@3.6.1
bash@5.2.15-2+b2
bsdutils@1:2.38.1-5+deb12u1
ca-certificates@20230311
coreutils@9.1-1
curl@7.88.1-10+deb12u5
dash@0.5.12-2
debconf@1.5.82
debian-archive-keyring@2023.3+deb12u1
debianutils@5.7-0.5~deb12u1
diffutils@1:3.8-4
dpkg@1.21.22
e2fsprogs@1.47.0-2
findutils@4.9.0-4
fontconfig-config@2.14.1-4
fonts-dejavu-core@2.37-6
gcc-12-base@12.2.0-14
gettext-base@0.21-12
gpgv@2.2.40-1.1
grep@3.8-5
gzip@1.12-1
hostname@3.23+nmu1
init-system-helpers@1.65.2
libabsl20220623@20220623.1-1
libacl1@2.3.1-3
libaom3@3.6.0-1
libapt-pkg6.0@2.6.1
libattr1@1:2.5.1-4
libaudit-common@1:3.0.9-1
libaudit1@1:3.0.9-1
libavif15@0.11.1-1
libblkid1@2.38.1-5+deb12u1
libbrotli1@1.0.9-2+b6
libbsd0@0.11.7-2
libbz2-1.0@1.0.8-5+b1
libc-bin@2.36-9+deb12u7
libc6@2.36-9+deb12u7
libcap-ng0@0.8.3-1+b3
libcap2@1:2.66-4
libcom-err2@1.47.0-2
libcrypt1@1:4.4.33-2
libcurl4@7.88.1-10+deb12u5
libdav1d6@1.0.0-2+deb12u1
libdb5.3@5.3.28+dfsg2-1
libde265-0@1.0.11-1+deb12u2
libdebconfclient0@0.270
libdeflate0@1.14-1
libedit2@3.1-20221030-2
libexpat1@2.5.0-1
libext2fs2@1.47.0-2
libffi8@3.4.4-1
libfontconfig1@2.14.1-4
libfreetype6@2.12.1+dfsg-5
libgav1-1@0.18.0-1+b1
libgcc-s1@12.2.0-14
libgcrypt20@1.10.1-3
libgd3@2.3.3-9
libgeoip1@1.6.12-10
libgmp10@2:6.2.1+dfsg1-1.1
libgnutls30@3.7.9-2+deb12u2
libgpg-error0@1.46-1
libgssapi-krb5-2@1.20.1-2+deb12u1
libheif1@1.15.1-1
libhogweed6@3.8.1-2
libicu72@72.1-3
libidn2-0@2.3.3-1+b1
libjbig0@2.1-6.1
libjpeg62-turbo@1:2.1.5-2
libk5crypto3@1.20.1-2+deb12u1
libkeyutils1@1.6.3-2
libkrb5-3@1.20.1-2+deb12u1
libkrb5support0@1.20.1-2+deb12u1
libldap-2.5-0@2.5.13+dfsg-5
liblerc4@4.0.0+ds-2
liblz4-1@1.9.4-1
liblzma5@5.4.1-0.2
libmd0@1.0.4-2
libmount1@2.38.1-5+deb12u1
libnettle8@3.8.1-2
libnghttp2-14@1.52.0-1+deb12u1
libnuma1@2.0.16-1
libp11-kit0@0.24.1-2
libpam-modules-bin@1.5.2-6+deb12u1
libpam-modules@1.5.2-6+deb12u1
libpam-runtime@1.5.2-6+deb12u1
libpam0g@1.5.2-6+deb12u1
libpcre2-8-0@10.42-1
libpng16-16@1.6.39-2
libpsl5@0.21.2-1
librav1e0@0.5.1-6
librtmp1@2.4+20151223.gitfa8646d.1-2+b2
libsasl2-2@2.1.28+dfsg-10
libsasl2-modules-db@2.1.28+dfsg-10
libseccomp2@2.5.4-1+b3
libselinux1@3.4-1+b6
libsemanage-common@3.4-1
libsemanage2@3.4-1+b5
libsepol2@3.4-2.1
libsmartcols1@2.38.1-5+deb12u1
libss2@1.47.0-2
libssh2-1@1.10.0-3+b1
libssl3@3.0.11-1~deb12u2
libstdc++6@12.2.0-14
libsvtav1enc1@1.4.1+dfsg-1
libsystemd0@252.22-1~deb12u1
libtasn1-6@4.19.0-2
libtiff6@4.5.0-6+deb12u1
libtinfo6@6.4-4
libudev1@252.22-1~deb12u1
libunistring2@1.0-2
libuuid1@2.38.1-5+deb12u1
libwebp7@1.2.4-0.2+deb12u1
libx11-6@2:1.8.4-2+deb12u2
libx11-data@2:1.8.4-2+deb12u2
libx265-199@3.5-2+b1
libxau6@1:1.0.9-1
libxcb1@1.15-1
libxdmcp6@1:1.1.2-3
libxml2@2.9.14+dfsg-1.3~deb12u1
libxpm4@1:3.5.12-1.1+deb12u1
libxslt1.1@1.1.35-1
libxxhash0@0.8.1-1
libyuv0@0.0~git20230123.b2528b0-1
libzstd1@1.5.4+dfsg2-5
login@1:4.13+dfsg1-1+b1
logsave@1.47.0-2
mawk@1.3.4.20200120-3.1
mount@2.38.1-5+deb12u1
ncurses-base@6.4-4
ncurses-bin@6.4-4
nginx-module-geoip@1.25.5-1~bookworm
nginx-module-image-filter@1.25.5-1~bookworm
nginx-module-njs@1.25.5+0.8.4-3~bookworm
nginx-module-xslt@1.25.5-1~bookworm
nginx@1.25.5-1~bookworm
openssl@3.0.11-1~deb12u2
passwd@1:4.13+dfsg1-1+b1
perl-base@5.36.0-7+deb12u1
sed@4.9-1
sysvinit-utils@3.06-4
tar@1.34+dfsg-1.2+deb12u1
tzdata@2024a-0+deb12u1
usr-is-merged@37~deb12u1
util-linux-extra@2.38.1-5+deb12u1
util-linux@2.38.1-5+deb12u1
zlib1g@1:1.2.13.dfsg-1