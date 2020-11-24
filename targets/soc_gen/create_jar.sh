#!/bin/bash

set -e
set -u

lein uberjar
rm -rf jardir
mkdir jardir
cd jardir
echo "extract uberjar"
unzip -q ../target/uberjar/soc_gen-0.1.0-SNAPSHOT-standalone.jar
echo "extract vmagic"
unzip -q vmagic-0.4-SNAPSHOT.jar 'de/*'
echo "extract vmagic-parse"
unzip -q vmagic-parser-0.4-SNAPSHOT.jar 'de/*'
rm *.jar
echo "rebuild soc_gen.jar"
jar cmf META-INF/MANIFEST.MF ../soc_gen.jar .
cd ..
rm -rf jardir
