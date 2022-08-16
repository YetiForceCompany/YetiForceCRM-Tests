#! /bin/bash
set -e
echo " -----  printenv -----"

printenv

echo " ----- 1  DATABASE_VERSION -----"
echo DATABASE_VERSION

echo " ----- 2  ${DATABASE_VERSION} -----"
echo ${DATABASE_VERSION}