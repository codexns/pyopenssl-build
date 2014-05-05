$ErrorActionPreference = "Stop"

$opensslVersion = '1.0.1g'

$winDir = split-path -parent $MyInvocation.MyCommand.Path
$buildDir = join-path $winDir .\py26-win32
$depsDir = join-path $winDir .\deps

# From http://stackoverflow.com/questions/4384814/how-to-call-batch-script-from-powershell/4385011#4385011
&$winDir\invoke-environment '"C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\bin\vcvars32.bat"'

if (!(test-path $buildDir)) {
    new-item $buildDir -itemtype directory
}

if (!(test-path $depsDir)) {
    new-item $depsDir -itemtype directory
}

cd $depsDir


$webclient = new-object System.Net.WebClient


if (!(test-path .\nasm-2.11-win32.zip)) {
    $webclient.DownloadFile("http://www.nasm.us/pub/nasm/releasebuilds/2.11/win32/nasm-2.11-win32.zip", "$depsDir\nasm-2.11-win32.zip")
}
if (!(test-path .\nasm-2.11)) {
    &"${env:ProgramFiles}\7-Zip\7z.exe" x -y .\nasm-2.11-win32.zip
}
$env:PATH="$depsDir\nasm-2.11;${env:PATH}"


if (!(test-path .\strawberry-perl-5.18.2.1-32bit-portable.zip)) {
    $webclient.DownloadFile("http://strawberryperl.com/download/5.18.2.1/strawberry-perl-5.18.2.1-32bit-portable.zip", "$depsDir\strawberry-perl-5.18.2.1-32bit-portable.zip")
}
if (!(test-path .\perl)) {
    new-item .\perl -itemtype directory
    cd .\perl\
    &"${env:ProgramFiles}\7-Zip\7z.exe" x -y ..\strawberry-perl-5.18.2.1-32bit-portable.zip
    cd ..
}
$env:PATH="$depsDir\perl\perl\site\bin;$depsDir\perl\perl\bin;$depsDir\perl\c\bin;${env:PATH}"
$env:TERM="dumb"


if (!(test-path .\openssl-$opensslVersion.tar.gz)) {
    $webclient.DownloadFile("http://www.openssl.org/source/openssl-$opensslVersion.tar.gz", "$depsDir\openssl-$opensslVersion.tar.gz")
}
if (test-path .\openssl-$opensslVersion) {
    remove-item -recurse $depsDir\openssl-$opensslVersion
}
&"${env:ProgramFiles}\7-Zip\7z.exe" x -y .\openssl-$opensslVersion.tar.gz
&"${env:ProgramFiles}\7-Zip\7z.exe" x -y .\openssl-$opensslVersion.tar
remove-item .\openssl-$opensslVersion.tar

if (test-path $buildDir\openssl-$opensslVersion) {
    remove-item -recurse $buildDir\openssl-$opensslVersion
}
move-item .\openssl-$opensslVersion $buildDir\openssl-$opensslVersion

if (!(test-path $buildDir\out)) {
    new-item $buildDir\out -itemtype directory
}

cd $buildDir\openssl-$opensslVersion\
perl Configure VC-WIN32 shared no-md2 no-rc5 no-ssl2 --prefix=$buildDir\out
.\ms\do_nasm.bat
nmake.exe -f .\ms\ntdll.mak
nmake.exe -f .\ms\ntdll.mak install
cd ..

$env:LIB="$buildDir\out\lib;${env:LIB}"
$env:INCLUDE="$buildDir\out\include;${env:INCLUDE}"
$env:PATH="$buildDir\out\bin;${env:PATH}"
c:\Python26-x86\Scripts\pip.exe install cryptography

cd ..
