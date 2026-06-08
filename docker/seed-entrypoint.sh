#!/bin/sh
set -e
tar xzf /seed/data.tar.gz -C /target/data
cp /seed/dump.sql.gz /target/db-init/dump.sql.gz
