$ErrorActionPreference = "Stop"

$opensslVersion = '1.0.1j'

$winDir = split-path -parent $MyInvocation.MyCommand.Path
$buildDir = join-path $winDir .\py33-win32
$depsDir = join-path $winDir .\deps
$stagingDir = join-path $buildDir .\staging
$tmpDir = join-path $buildDir .\tmp
$outDir = join-path $winDir ..\out\py33_windows_x32

# From http://stackoverflow.com/questions/4384814/how-to-call-batch-script-from-powershell/4385011#4385011
&$winDir\invoke-environment '"C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\vcvars32.bat"'

if (!(test-path $buildDir)) {
    new-item $buildDir -itemtype directory
}

if (!(test-path $depsDir)) {
    new-item $depsDir -itemtype directory
}

if (!(test-path $stagingDir)) {
    new-item $stagingDir -itemtype directory
}

if (test-path $tmpDir) {
    remove-item -recurse -force $tmpDir
}
new-item $tmpDir -itemtype directory

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


if (!(test-path .\openssl-$opensslVersion)) {
    if (!(test-path .\openssl-$opensslVersion.tar.gz)) {
        $webclient.DownloadFile("http://www.openssl.org/source/openssl-$opensslVersion.tar.gz", "$depsDir\openssl-$opensslVersion.tar.gz")
    }

    &"${env:ProgramFiles}\7-Zip\7z.exe" x -y .\openssl-$opensslVersion.tar.gz
    &"${env:ProgramFiles}\7-Zip\7z.exe" x -y .\openssl-$opensslVersion.tar
    remove-item .\openssl-$opensslVersion.tar
}

if (test-path $buildDir\openssl-$opensslVersion) {
    # Try twice to prevent locking issues
    try {
        remove-item -recurse -force $buildDir\openssl-$opensslVersion
    } catch {
        remove-item -recurse -force $buildDir\openssl-$opensslVersion
    }
}
copy-item -recurse .\openssl-$opensslVersion $buildDir\

cd $buildDir\openssl-$opensslVersion\
perl Configure VC-WIN32 no-md2 no-rc5 no-ssl2 --prefix=$stagingDir

move-item .\ms\libeay32.def .\ms\libeay32mt.def
move-item .\ms\ssleay32.def .\ms\ssleay32mt.def
(get-content .\ms\nt.mak | foreach-object {$_ -replace '^SSL=ssleay32$', 'SSL=ssleay32mt' -replace '^CRYPTO=libeay32$', 'CRYPTO=libeay32mt'}) | set-content .\ms\nt.mak

.\ms\do_nasm.bat
nmake.exe -f .\ms\nt.mak
nmake.exe -f .\ms\nt.mak install
cd ..

$env:LIB="$stagingDir\lib;${env:LIB}"
$env:INCLUDE="$stagingDir\include;${env:INCLUDE}"
$env:PATH="$stagingDir\bin;${env:PATH}"
c:\Python33-x86\Scripts\pip.exe uninstall -y cryptography pyopenssl
c:\Python33-x86\Scripts\pip.exe install --build "$tmpDir" --no-use-wheel cryptography pyopenssl

$pyopensslVersion = ""
c:\Python33-x86\Scripts\pip.exe show pyopenssl | foreach-object {
    $splitLine = $_.split(": ")
    if ($splitLine[0] -eq "Version") {
        $pyopensslVersion = $splitLine[2]
    }
}

$cryptographyVersion = ""
c:\Python33-x86\Scripts\pip.exe show cryptography | foreach-object {
    $splitLine = $_.split(": ")
    if ($splitLine[0] -eq "Version") {
        $cryptographyVersion = $splitLine[2]
    }
}

cd ..

if (test-path $outDir) {
    remove-item -recurse -force $outDir
}
new-item $outDir -itemtype directory

copy-item C:\Python33-x86\Lib\site-packages\six.py $outDir\
copy-item C:\Python33-x86\Lib\site-packages\_cffi_backend.pyd $outDir\
copy-item -recurse C:\Python33-x86\Lib\site-packages\cffi $outDir\
copy-item -recurse C:\Python33-x86\Lib\site-packages\cryptography $outDir\
copy-item -recurse C:\Python33-x86\Lib\site-packages\pycparser $outDir\
copy-item -recurse C:\Python33-x86\Lib\site-packages\OpenSSL $outDir\
copy-item $stagingDir\bin\libeay32.dll $outDir\cryptography\
copy-item $stagingDir\bin\ssleay32.dll $outDir\cryptography\

&"${env:ProgramFiles}\7-Zip\7z.exe" a -r -tzip $outDir\..\cryptography-${cryptographyVersion}_pyopenssl-${pyopensslVersion}_openssl-${opensslVersion}_py33_windows-x32.zip $outDir\*
