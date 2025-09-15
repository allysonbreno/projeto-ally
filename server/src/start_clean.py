#!/usr/bin/env python3
"""
Script para iniciar o servidor com cache limpo
"""
import os
import sys
import shutil
import importlib

# Limpar variáveis de ambiente relacionadas ao Python
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
os.environ['PYTHONUNBUFFERED'] = '1'

# Limpar cache de módulos já carregados
modules_to_clear = []
for module_name in list(sys.modules.keys()):
    if any(name in module_name for name in ['players', 'enemies', 'maps', 'db']):
        modules_to_clear.append(module_name)

for module_name in modules_to_clear:
    if module_name in sys.modules:
        del sys.modules[module_name]
        print(f"[CACHE_CLEAR] Módulo {module_name} removido do cache")

# Limpar diretórios __pycache__
def remove_pycache_dirs(root_dir):
    for root, dirs, files in os.walk(root_dir):
        if '__pycache__' in dirs:
            pycache_path = os.path.join(root, '__pycache__')
            shutil.rmtree(pycache_path, ignore_errors=True)
            print(f"[CACHE_CLEAR] Removido: {pycache_path}")

print("=== LIMPANDO CACHE DO PYTHON ===")
remove_pycache_dirs('.')

# Forçar recompilação
import py_compile
import glob

for py_file in glob.glob('**/*.py', recursive=True):
    if py_file != 'start_clean.py':
        try:
            py_compile.compile(py_file, doraise=True)
        except:
            pass

print("=== INICIANDO SERVIDOR COM CACHE LIMPO ===")

# Importar e executar o servidor
import game_server