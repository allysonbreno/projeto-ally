@echo off
echo Limpando cache do Python...
for /d /r . %%d in (__pycache__) do @if exist "%%d" rd /s /q "%%d"
del /s /q *.pyc 2>nul
echo Cache limpo!
echo.
echo Definindo variaveis de ambiente...
set PYTHONDONTWRITEBYTECODE=1
set PYTHONUNBUFFERED=1
echo.
echo Matando processos Python existentes...
taskkill /f /im python.exe >nul 2>&1
timeout /t 2 >nul
echo.
echo Iniciando servidor...
python game_server.py
pause