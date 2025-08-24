; Projeto Ally - Instalador NSIS
; Versão: v2.1

!define APPNAME "Projeto Ally"
!define COMPANYNAME "Project Brothers"
!define DESCRIPTION "Jogo 2D RPG - Sistema completo de aventura"
!define VERSIONMAJOR 2
!define VERSIONMINOR 1
!define VERSIONBUILD 0
!define HELPURL "https://github.com/allysonbreno/projeto-ally"
!define UPDATEURL "https://github.com/allysonbreno/projeto-ally/releases"
!define ABOUTURL "https://github.com/allysonbreno/projeto-ally"
!define INSTALLSIZE 50000  ; Tamanho estimado em KB (50MB)

RequestExecutionLevel admin

InstallDir "$PROGRAMFILES64\${APPNAME}"

LicenseData "README.md"
Name "${APPNAME}"
outFile "builds\${APPNAME} v${VERSIONMAJOR}.${VERSIONMINOR} Installer.exe"

!include LogicLib.nsh
!include x64.nsh

page license
page directory
page instfiles

!macro VerifyUserIsAdmin
UserInfo::GetAccountType
pop $0
${If} $0 != "admin"
    messageBox mb_iconstop "Permissões de administrador necessárias!"
    setErrorLevel 740
    quit
${EndIf}
!macroend

function .onInit
    setShellVarContext all
    !insertmacro VerifyUserIsAdmin
functionEnd

section "install"
    setOutPath $INSTDIR
    
    ; Copiar arquivos do jogo
    file "builds\projeto-ally.exe"
    file "builds\projeto-ally.pck"
    file "README.md"
    file "icon.svg"
    
    ; Escrever informações de desinstalação no registro
    writeUninstaller "$INSTDIR\uninstall.exe"
    
    ; Registry para Add/Remove Programs
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "DisplayName" "${APPNAME}"
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "InstallLocation" "$\"$INSTDIR$\""
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "DisplayIcon" "$\"$INSTDIR\projeto-ally.exe$\""
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "Publisher" "${COMPANYNAME}"
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "HelpLink" "${HELPURL}"
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "URLUpdateInfo" "${UPDATEURL}"
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "URLInfoAbout" "${ABOUTURL}"
    writeRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "DisplayVersion" "${VERSIONMAJOR}.${VERSIONMINOR}.${VERSIONBUILD}"
    writeRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "VersionMajor" ${VERSIONMAJOR}
    writeRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "VersionMinor" ${VERSIONMINOR}
    writeRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "NoModify" 1
    writeRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "NoRepair" 1
    writeRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}" "EstimatedSize" ${INSTALLSIZE}
    
    ; Criar atalhos
    createShortCut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\projeto-ally.exe"
    createShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\projeto-ally.exe"
sectionEnd

; Desinstalador
function un.onInit
    SetShellVarContext all
    
    MessageBox MB_OKCANCEL|MB_ICONQUESTION "Tem certeza que deseja desinstalar ${APPNAME}?" IDOK next
        Abort
    next:
    !insertmacro VerifyUserIsAdmin
functionEnd

section "uninstall"
    ; Remover arquivos
    delete $INSTDIR\projeto-ally.exe
    delete $INSTDIR\projeto-ally.pck
    delete $INSTDIR\README.md
    delete $INSTDIR\icon.svg
    delete $INSTDIR\uninstall.exe
    rmDir $INSTDIR
    
    ; Remover atalhos
    delete "$SMPROGRAMS\${APPNAME}.lnk"
    delete "$DESKTOP\${APPNAME}.lnk"
    
    ; Remover do registro
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${COMPANYNAME} ${APPNAME}"
sectionEnd