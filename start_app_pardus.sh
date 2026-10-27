#!/usr/bin/env bash
# FamilyToStudy - Pardus Linux Başlatıcı
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -d "$DIR/ios-app/build/web" ]; then
    WEB_DIR="$DIR/ios-app/build/web"
elif [ -d "$DIR/out" ]; then
    WEB_DIR="$DIR/out"
else
    echo "Web çıktısı hazırlanıyor..."
    cd "$DIR" && npm run build
    WEB_DIR="$DIR/out"
fi

# Eğer sunucu zaten çalışmıyorsa başlat
if ! curl -s -I http://127.0.0.1:5050/ >/dev/null 2>&1; then
    echo "FamilyToStudy sunucusu başlatılıyor..."
    python3 -m http.server 5050 --directory "$WEB_DIR" >/dev/null 2>&1 &
    sleep 1
fi

# Firefox ile uygulamayı aç
echo "Uygulama açılıyor: http://127.0.0.1:5050"
firefox --new-window http://127.0.0.1:5050 &
