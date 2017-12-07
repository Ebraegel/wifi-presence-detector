#!/bin/bash

set -u

curl -XPOST "https://maker.ifttt.com/trigger/${1}/with/key/${IFTTT_WEBHOOK_KEY}"
