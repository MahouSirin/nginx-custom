# nginx-custom
**My nginx build files.**

Inspired by [hakasenyang](https://github.com/hakasenyang/nginx-build).

Original source code can be found on [hg.nginx.org](https://hg.nginx.org/nginx-quic).

## 아래의 필수 라이브러리를 설치해주세요.
- Ubuntu / Debian - `apt install libjemalloc-dev uuid-dev libatomic1 libatomic-ops-dev expat unzip autoconf automake libtool libgd-dev libmaxminddb-dev libxslt1-dev libpcre2-dev libpcre3-dev cmake ninja-build golang-go zlib1g-dev libxml2-dev g++ curl`

## 설치 방법
1. 이 명령어를 이용하여 다운로드 합니다. - `git clone https://github.com/Raiden-Ei/nginx-custom.git --recursive`
2. 필수 라이브러리를 설치합니다. (이미 설치했다면 무시합니다.)
3. config.inc 를 수정합니다. (SERVER_HEADER, Modules, 기타.)
    - 처음 소스를 다운로드 받았다면 아래 명령어를 입력하여 먼저 복사한 뒤 편집합니다.
    - `cp config.inc.example config.inc`
4. `sudo ./auto.sh` 를 실행합니다.
5. 버전 및 오류를 테스트합니다: `nginx -v; nginx -t;`
6. `systemctl restart nginx` 를 실행합니다.
8. **끝!!**

## 기능 목록
- HTTP/3 with QUIC (by nginx)
- TLS v1.3 (**final**)
    - headers_more_nginx_module
    - 그 외 여러가지
- GeoIP2 Module
    - [여기](https://github.com/leev/ngx_http_geoip2_module)서 GeoIP2 에 대한 설정 예시를 참고하십시오.