#!/usr/bin/bash

source $(dirname "$0")/man_create.sh
target=$1

echo "build frontend"
echo

yes | rm -rf public
cd ffplayout-frontend

# for node version 17+
export NODE_OPTIONS=--openssl-legacy-provider
npm install
npm run build
mv dist ../public

unset NODE_OPTIONS

cd ..

if [[ -n $target ]]; then
    targets=($target)
else
    targets=("x86_64-unknown-linux-musl" "aarch64-unknown-linux-gnu" "x86_64-pc-windows-gnu" "x86_64-apple-darwin" "aarch64-apple-darwin")
fi

IFS="= "
while read -r name value; do
    if [[ $name == "version" ]]; then
        version=${value//\"/}
    fi
done < ffplayout-engine/Cargo.toml

echo "Compile ffplayout version is: \"$version\""
echo ""

for target in "${targets[@]}"; do
    echo "compile static for $target"
    echo ""

    if [[ $target == "x86_64-pc-windows-gnu" ]]; then
        if [[ -f "ffplayout-v${version}_${target}.zip" ]]; then
            rm -f "ffplayout-v${version}_${target}.zip"
        fi

        cargo build --release --target=$target

        cp ./target/${target}/release/ffpapi.exe .
        cp ./target/${target}/release/ffplayout.exe .
        zip -r "ffplayout-v${version}_${target}.zip" assets docs public LICENSE README.md CHANGELOG.md ffplayout.exe ffpapi.exe -x *.db
        rm -f ffplayout.exe ffpapi.exe
    elif [[ $target == "x86_64-apple-darwin" ]] || [[ $target == "aarch64-apple-darwin" ]]; then
        if [[ -f "ffplayout-v${version}_${target}.tar.gz" ]]; then
            rm -f "ffplayout-v${version}_${target}.tar.gz"
        fi
        c_cc="x86_64-apple-darwin20.4-clang"
        c_cxx="x86_64-apple-darwin20.4-clang++"

        if [[ $target == "aarch64-apple-darwin" ]]; then
            c_cc="aarch64-apple-darwin20.4-clang"
            c_cxx="aarch64-apple-darwin20.4-clang++"
        fi

        CC="$c_cc" CXX="$c_cxx" cargo build --release --target=$target

        cp ./target/${target}/release/ffpapi .
        cp ./target/${target}/release/ffplayout .
        tar -czvf "ffplayout-v${version}_${target}.tar.gz" --exclude='*.db' assets docs public LICENSE README.md CHANGELOG.md ffplayout ffpapi
        rm -f ffplayout ffpapi
    else
        if [[ -f "ffplayout-v${version}_${target}.tar.gz" ]]; then
            rm -f "ffplayout-v${version}_${target}.tar.gz"
        fi

        cargo build --release --target=$target

        cp ./target/${target}/release/ffpapi .
        cp ./target/${target}/release/ffplayout .
        tar -czvf "ffplayout-v${version}_${target}.tar.gz" --exclude='*.db' assets docs public LICENSE README.md CHANGELOG.md ffplayout ffpapi
        rm -f ffplayout ffpapi
    fi

    echo ""
done

if [[ "${#targets[@]}" == "5" ]] || [[ $targets == "x86_64-unknown-linux-musl" ]]; then
    cargo deb --target=x86_64-unknown-linux-musl -p ffplayout --manifest-path=ffplayout-engine/Cargo.toml -o ffplayout_${version}_amd64.deb
    cd ffplayout-engine
    cargo generate-rpm --target=x86_64-unknown-linux-musl -o ../ffplayout-${version}-1.x86_64.rpm

    cd ..
fi

if [[ "${#targets[@]}" == "5" ]] || [[ $targets == "aarch64-unknown-linux-gnu" ]]; then
    cargo deb --target=aarch64-unknown-linux-gnu --variant=arm64 -p ffplayout --manifest-path=ffplayout-engine/Cargo.toml -o ffplayout_${version}_arm64.deb
fi
