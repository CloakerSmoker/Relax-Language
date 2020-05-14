import sys
import os
import os.path as path
import subprocess
from shutil import copyfile
from shutil import rmtree
from shutil import move
from colorama import init, Fore, Back, Style

# Uses stable_version.exe to compile the most recent version of the source, and then 
#  tests the new version of the compiled source (to ensure source changes haven't broken any part of the compiler)

# ONLY COMMIT AFTER A NEW VERSION PASSES THIS SCRIPT

init(autoreset=True)
cwd = os.getcwd()
path_join = os.path.join

safe_compiler = path_join(cwd, 'stable_version.exe')
compile_command = f'{safe_compiler} Bain.rlx testing.exe'
compiler_output = path_join(cwd, 'testing.exe')

compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True)
stderr_text = compile_result.stderr.decode('UTF-8')

if compile_result.returncode != 1 or len(stderr_text) != 0:
    print(f'{Fore.LIGHTRED_EX}Compile error:\n{stderr_text}', file=sys.stderr)
    sys.exit(1)

test_script = path_join(cwd, 'test_compiler.py')
test_command = f'python {test_script} {compiler_output}'

test_result = subprocess.run(test_command, cwd=cwd, shell=True, capture_output=True)
stderr_text = test_result.stderr.decode('UTF-8')

if len(stderr_text):
    print(f'{Fore.LIGHTRED_EX}Output file failed 1+ test:\n{stderr_text}', file=sys.stderr)
    os.remove(compiler_output)
    sys.exit(1)

print(f'{Fore.LIGHTGREEN_EX}Output file passed all tests.')
move(compiler_output, 'new_stable.exe')