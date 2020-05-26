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

recursion_count = 3

if len(sys.argv) == 2:
    recursion_count = int(sys.argv[1])

safe_compiler = path_join(cwd, 'stable_version.exe')

for i in range(0, recursion_count):
    compile_command = f'{safe_compiler} -i Bain.rlx -o testing{i}.exe'
    compiler_output = path_join(cwd, f'testing{i}.exe')

    compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True)

    stderr_text = compile_result.stderr.decode('UTF-8')

    if compile_result.returncode != 1 or len(stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}Compile error ({hex(compile_result.returncode)}):\n{stderr_text}', file=sys.stderr)
        sys.exit(1)
    
    if i != 0:
        os.remove(safe_compiler)

    test_script = path_join(cwd, 'test_compiler.py')
    test_command = f'python {test_script} {compiler_output}'

    test_result = subprocess.run(test_command, cwd=cwd, shell=True, capture_output=True)
    stderr_text = test_result.stderr.decode('UTF-8')

    if len(stderr_text):
        print(f'{Fore.LIGHTRED_EX}Output file iteration {i + 1} failed 1+ test:\n{stderr_text}', file=sys.stderr)
        #os.remove(compiler_output)
        sys.exit(1)
    
    print(f'{Fore.LIGHTGREEN_EX}Output file iteration {i + 1} passed all tests.')
    safe_compiler = compiler_output

print(f'{Fore.LIGHTGREEN_EX}Output file(s) passed all tests.')
move(compiler_output, 'new_stable.exe')