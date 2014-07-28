echo off
echo ------ geos -----

::CALL bsdtar xvf %PKGDIR%\geos-%GEOS_VERSION%.tar.bz2
::IF ERRORLEVEL 1 GOTO ERROR

::CALL rename geos-%GEOS_VERSION% geos
::IF ERRORLEVEL 1 GOTO ERROR


::LATEST SNAPSHOT 18.05.2014
echo.
echo Download latest snapshot http://geos.osgeo.org/snapshots/
echo and extract to %ROOTDIR%\geos
echo.
pause

cd geos

CALL autogen.bat
IF ERRORLEVEL 1 GOTO ERROR

IF %BUILDPLATFORM% EQU x64 (
    CALL nmake /A /F makefile.vc MSVC_VER=1800 WIN64=YES
) ELSE (
    CALL nmake /A /F makefile.vc MSVC_VER=1800
)
IF ERRORLEVEL 1 GOTO ERROR

GOTO DONE

:ERROR
echo ----------ERROR geos --------------

:DONE

cd %ROOTDIR%
EXIT /b %ERRORLEVEL%