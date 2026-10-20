#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
perl Makefile.PL
make
perl -Mblib tests/binding_test.pl
rm -f Licensebox-0.3.0.tar.gz
make dist
rm -rf build/consumer
mkdir -p build/consumer
tar -xzf Licensebox-0.3.0.tar.gz -C build/consumer
(cd build/consumer/Licensebox-0.3.0 && perl Makefile.PL && make && perl -Mblib -MLicensebox -e 'die unless $Licensebox::VERSION eq "0.3.0"; die unless Licensebox::native_binding("demo") =~ /^m1:/')
