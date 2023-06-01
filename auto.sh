#!/bin/sh

### Read config
if [ ! -f "config.inc" ]; then
    echo "--- The configuration file (config.inc) could not be found. Apply as default setting. ---"
    echo "--- All additional modules are not used. ---"
else
    . ./config.inc
fi

### If the value is incorrect, convert to normal data.
if [ ! "$SERVER_HEADER" ]; then SERVER_HEADER="raiden"; fi
if [ "$BITCHK" != 32 ] && [ "$BITCHK" != 64 ]; then BITCHK=32; fi
if [ ! "$LTO" ]; then LTO=0; fi
if [ ! "$BUILD_MTS" ]; then BUILD_MTS="-j2"; fi
if [ ! "$NGX_PREFIX" ]; then NGX_PREFIX="/etc/nginx"; fi
if [ ! "$NGX_SBIN_PATH" ]; then NGX_SBIN_PATH="/usr/sbin/nginx"; fi
if [ ! "$NGX_CONF" ]; then NGX_CONF="/etc/nginx/nginx.conf"; fi
if [ ! "$NGX_LIB" ]; then NGX_LIB="/var/lib/nginx"; fi
if [ ! "$NGX_LOG" ]; then NGX_LOG="/var/log/nginx"; fi
if [ ! "$NGX_PID" ]; then NGX_PID="/var/run/nginx.pid"; fi
if [ ! "$NGX_LOCK" ]; then NGX_LOCK="/var/lock/nginx.lock"; fi

### Remove Old file
rm -f ${NGX_SBIN_PATH}.old

### Multithread build
BUILD_MTS="-j$(expr $(nproc) \+ 1)"

git submodule update --init --recursive

### ZLIB reconf
if [ "$BITCHK" = 64 ]; then
    if [ ! -f "lib/zlib/Makefile" ]; then
        cd lib/zlib
        ./configure --64
        cd ../..
    fi
else
    if [ ! -f "lib/zlib_x86/Makefile" ]; then
        git submodule add --force https://github.com/madler/zlib.git lib/zlib_x86
        cd lib/zlib_x86
        ./configure
        cd ../..
    fi
fi

### PSOL Download (PageSpeed)
#if [ ! -d "lib/pagespeed" ] && [ "$PAGESPEED" = 1 ]; then
    ### Download pagespeed
#    cd lib
#    wget -c 'https://codeload.github.com/apache/incubator-pagespeed-ngx/zip/latest-beta'
#    unzip latest-beta
#    rm -f latest-beta
#    cd incubator-pagespeed-ngx-latest-beta

    ### Download psol
#    curl "$(scripts/format_binary_url.sh PSOL_BINARY_URL)" | tar xz
#    cd ..
#    mv incubator-pagespeed-ngx-latest-beta pagespeed
#    cd ..
#fi

### x86, x64 Check (Configuration)
if [ "$BITCHK" = 64 ]; then
    BUILD_BIT="-m64 "
    BUILD_ZLIB="./lib/zlib"
    BUILD_LD="-lrt -ljemalloc -Wl,-z,relro -Wl,-z,now -fPIC"
else
    BUILD_BIT=""
    BUILD_ZLIB="./lib/zlib_x86"
    BUILD_LD=""
fi

### LTO Build
if [ "$LTO" = 1 ]; then
    BUILD_LTO="-flto -ffat-lto-objects"
    BUILD_OPENSSL_LTO="-flto -ffat-lto-objects"
else
    BUILD_LTO=""
    BUILD_OPENSSL_LTO=""
fi

### Build BoringSSL
### Use ninja-build for performance
if [ ! -d "lib/boringssl/build" ]; then
    cd lib/boringssl
    mkdir build
    cd build
    cmake -GNinja ..
    ninja
    cd ..
    ### Make symlink to './include' with OpenSSL Library
    mkdir -p .openssl/lib
    cd .openssl
    ln -s ../include include
    cd ..
    ### Copy BoringSSL's crypto libraries to OpenSSL Library directory
    cp build/crypto/libcrypto.a .openssl/lib
    cp build/ssl/libssl.a .openssl/lib
    cd ../..
fi

### Temporary Ubuntu/Debian build error (libxslt/libxml2)
### URL : https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=721602
TEMP_OPT="-lm"

### Module check
#if [ "$PAGESPEED" = 1 ]; then BUILD_MODULES="--add-module=./lib/pagespeed ${PS_NGX_EXTRA_FLAGS}"; fi
if [ "$FLV" = 1 ]; then BUILD_MODULES="${BUILD_MODULES} --add-module=./lib/nginx-http-flv-module"; fi
if [ "$NAXSI" = 1 ]; then BUILD_MODULES="${BUILD_MODULES} --add-module=./lib/naxsi/naxsi_src"; fi
if [ "$DAV_EXT" = 1 ]; then BUILD_MODULES="${BUILD_MODULES} --add-module=./lib/nginx-dav-ext-module"; fi
if [ "$FANCYINDEX" = 1 ]; then BUILD_MODULES="${BUILD_MODULES} --add-module=./lib/ngx-fancyindex"; fi
if [ "$GEOIP2" = 1 ]; then BUILD_MODULES="${BUILD_MODULES} --add-module=./lib/ngx_http_geoip2_module"; fi
if [ "$VTS" = 1 ]; then BUILD_MODULES="${BUILD_MODULES} --add-module=./lib/nginx-module-vts"; fi

auto/configure \
--with-cc-opt="-Wno-stringop-truncation -DTCP_FASTOPEN=23 ${BUILD_BIT}${BUILD_LTO} ${TEMP_OPT} -g -O3 -march=native -fstack-protector-strong -fuse-ld=gold -fuse-linker-plugin --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-strict-aliasing -Wp,-D_FORTIFY_SOURCE=2 -gsplit-dwarf -DNGX_HTTP_HEADERS" \
--with-ld-opt="${BUILD_LD} ${BUILD_LTO}" \
--with-openssl-opt="no-cmp no-ssl3-method -march=native -ljemalloc ${BUILD_OPENSSL_LTO}" \
--builddir=objs --prefix=${NGX_PREFIX} \
--conf-path=${NGX_CONF} \
--pid-path=${NGX_PID} \
--lock-path=${NGX_LOCK} \
--http-log-path=${NGX_LOG}/access.log \
--error-log-path=${NGX_LOG}/error.log \
--sbin-path=${NGX_SBIN_PATH} \
--http-client-body-temp-path=${NGX_LIB}/client_body_temp \
--http-proxy-temp-path=${NGX_LIB}/proxy_temp \
--http-fastcgi-temp-path=${NGX_LIB}/fastcgi_temp \
--http-scgi-temp-path=${NGX_LIB}/scgi_temp \
--http-uwsgi-temp-path=${NGX_LIB}/uwsgi_temp \
--with-zlib=${BUILD_ZLIB} \
--with-openssl=./lib/boringssl \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_stub_status_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_slice_module \
--with-http_gzip_static_module \
--with-http_auth_request_module \
--with-http_dav_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_image_filter_module \
--with-file-aio \
--with-threads \
--with-libatomic \
--with-mail \
--with-compat \
--with-stream \
--with-http_ssl_module \
--with-mail_ssl_module \
--with-http_v2_module \
--with-http_v3_module \
--with-stream_ssl_module \
--with-stream_realip_module \
--with-stream_ssl_preread_module \
--add-module=./lib/ngx_devel_kit \
--add-module=./lib/ngx_brotli \
--add-module=./lib/headers-more-nginx-module \
${BUILD_MODULES}

### Skip OpenSSL Build to prevent Error 127
touch lib/boringssl/.openssl/include/openssl/ssl.h

### SERVER HEADER CONFIG
NGX_AUTO_CONFIG_H="objs/ngx_auto_config.h";have="NGINX_SERVER";value="\"${SERVER_HEADER}\""; . auto/define

### Install
make $BUILD_MTS install

### Make directory NGX_LIB
mkdir -p ${NGX_LIB}

### Write systemd file
if [ ! -f "/lib/systemd/system/nginx.service" ]; then
  echo "Could not find systemd service file. Creating new one..";
  cat > /lib/systemd/system/nginx.service <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable nginx.service

fi

### Check for old files
if [ -f "${NGX_SBIN_PATH}.old" ]; then
    ### Test nginx configuration.
    "$NGX_SBIN_PATH" -t > /dev/null 2>&1
    if test $? -ne 0; then
        echo "Failed nginx configuration test."
        exit 1
    fi
    sleep 1
    rm ${NGX_SBIN_PATH}.old
    systemctl restart nginx
fi
