#!/bin/bash
VERSION=${1}
helm fetch ingress-nginx/ingress-nginx --version ${VERSION}

