$ErrorActionPreference = "Stop"

$opensslVersion = '1.0.2d'

$winDir = split-path -parent $MyInvocation.MyCommand.Path
$buildDir = join-path $winDir .\py33-amd64
$depsDir = join-path $winDir .\deps
$stagingDir = join-path $buildDir .\staging
$tmpDir = join-path $buildDir .\tmp
$outDir = join-path $winDir ..\out\py33_windows_x64

# From http://stackoverflow.com/questions/4384814/how-to-call-batch-script-from-powershell/4385011#4385011
&$winDir\invoke-environment '"C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64\vcvars64.bat"'

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
perl Configure VC-WIN64A no-md2 no-rc5 no-ssl2 --prefix=$stagingDir
.\ms\do_win64a.bat

move-item .\ms\libeay32.def .\ms\libeay32mt.def
move-item .\ms\ssleay32.def .\ms\ssleay32mt.def
(get-content .\ms\nt.mak | foreach-object {$_ -replace '^SSL=ssleay32$', 'SSL=ssleay32mt' -replace '^CRYPTO=libeay32$', 'CRYPTO=libeay32mt'}) | set-content .\ms\nt.mak

nmake.exe -f .\ms\nt.mak
nmake.exe -f .\ms\nt.mak install
cd ..

$env:LIB="$stagingDir\lib;${env:LIB}"
$env:INCLUDE="$stagingDir\include;${env:INCLUDE}"
$env:PATH="$stagingDir\bin;${env:PATH}"
c:\Python33\Scripts\pip.exe uninstall -y cryptography pyopenssl cffi six pycparser
c:\Python33\Scripts\pip.exe install --build "$tmpDir" --no-use-wheel cryptography pyopenssl

$pyopensslVersion = ""
c:\Python33\Scripts\pip.exe show pyopenssl | foreach-object {
    $splitLine = $_.split(": ")
    if ($splitLine[0] -eq "Version") {
        $pyopensslVersion = $splitLine[2]
    }
}

$cryptographyVersion = ""
c:\Python33\Scripts\pip.exe show cryptography | foreach-object {
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

copy-item C:\Python33\Lib\site-packages\six.py $outDir\
copy-item C:\Python33\Lib\site-packages\_cffi_backend.pyd $outDir\
copy-item -recurse C:\Python33\Lib\site-packages\cffi $outDir\
copy-item -recurse C:\Python33\Lib\site-packages\cryptography $outDir\
copy-item -recurse C:\Python33\Lib\site-packages\pycparser $outDir\
copy-item -recurse C:\Python33\Lib\site-packages\OpenSSL $outDir\

&"${env:ProgramFiles}\7-Zip\7z.exe" a -r -tzip $outDir\..\cryptography-${cryptographyVersion}_pyopenssl-${pyopensslVersion}_openssl-${opensslVersion}_py33_windows-x64.zip $outDir\*