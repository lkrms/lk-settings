@ECHO OFF

NET SESSION >NUL 2>NUL || (
    ECHO Please use "Run as administrator"
    PAUSE
    EXIT /B 1
)

CALL :log Uninstalling OneDrive
"%SystemRoot%\SysWOW64\OneDriveSetup.exe" /uninstall

CALL :log Disabling reserved storage
DISM /Online /Set-ReservedStorageState /State:Disabled

:: CALL :log Setting hostname
:: WMIC COMPUTERSYSTEM WHERE Name="%computername%" CALL Rename win10

CALL :log Configuring virtual memory
WMIC COMPUTERSYSTEM WHERE Name="%computername%" SET AutomaticManagedPagefile=FALSE
WMIC PAGEFILESET SET InitialSize=512,MaximumSize=512

PAUSE
EXIT /B

:log
ECHO [%DATE% %TIME%] %*
EXIT /B
