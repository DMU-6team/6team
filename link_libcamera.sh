#!/bin/bash

# 1. 현재 활성화된 가상환경 확인
if [ -z "$VIRTUAL_ENV" ]; then
    echo "❌ 가상환경이 활성화되어 있지 않습니다. 먼저 가상환경을 활성화하세요."
    exit 1
fi

SITE_PACKAGES=$(find $VIRTUAL_ENV/lib -type d -name "site-packages")

# 2. 시스템 경로의 libcamera 위치 확인
SYS_LIBCAMERA="/usr/lib/python3/dist-packages/libcamera"

if [ ! -d "$SYS_LIBCAMERA" ]; then
    echo "❌ 시스템에 libcamera 모듈이 설치되어 있지 않습니다: $SYS_LIBCAMERA"
    echo "📦 설치 예: sudo apt install -y python3-libcamera"
    exit 1
fi

# 3. 이미 링크가 있는지 확인
if [ -L "$SITE_PACKAGES/libcamera" ]; then
    echo "ℹ️ 이미 libcamera가 링크되어 있습니다: $SITE_PACKAGES/libcamera"
else
    ln -s "$SYS_LIBCAMERA" "$SITE_PACKAGES/libcamera"
    echo "✅ libcamera 모듈이 가상환경에 연결되었습니다!"
fi
