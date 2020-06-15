import sys
import os
import os.path as path
import subprocess
import platform
from shutil import copyfile
from shutil import rmtree
from shutil import move
from colorama import init, Fore, Back, Style
from difflib import SequenceMatcher

# Uses stable_version.exe to compile the most recent version of the source, and then 
#  tests the new version of the compiled source (to ensure source changes haven't broken any part of the compiler)

# ONLY COMMIT AFTER A NEW VERSION PASSES THIS SCRIPT

init(autoreset=True)
cwd = os.getcwd()
path_join = os.path.join

running_on = platform.system()

compile_command_format = '{} -i "{}" -o "{}"'
platform_extension = 'exe'

if running_on == 'Linux':
    compile_command_format = f'./{compile_command_format} --elf'
    platform_extension = 'elf'
elif running_on != 'Windows':
    print('Unsupported platform.', file=sys.stderr)
    sys.exit(1)

recursion_count = 3

if len(sys.argv) == 2:
    recursion_count = int(sys.argv[1])

safe_compiler = path_join(cwd, f'stable_version.{platform_extension}')

for i in range(0, recursion_count):
    compiler_output = path_join(cwd, f'testing{i}.{platform_extension}')
    compile_command = compile_command_format.format(safe_compiler, 'Bain.rlx', compiler_output)
    #f'{safe_compiler} -i Bain.rlx -o testing{i}.exe'

    compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True)

    stderr_text = compile_result.stderr.decode('UTF-8')

    if compile_result.returncode != 1 or len(stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}Compile error ({hex(compile_result.returncode)}):\n{stderr_text}', file=sys.stderr)
        sys.exit(1)

    test_script = path_join(cwd, 'test_compiler.py')
    test_command = f'python {test_script} {compiler_output}'

    test_result = subprocess.run(test_command, cwd=cwd, shell=True, capture_output=True)
    stderr_text = test_result.stderr.decode('UTF-8')

    if len(stderr_text):
        print(f'{Fore.LIGHTRED_EX}Output file iteration {i + 1} failed 1+ test:\n{stderr_text}', file=sys.stderr)
        #os.remove(compiler_output)
        sys.exit(1)
    
    # muh one liner though
    print(f'{Fore.LIGHTGREEN_EX}Output file iteration {i + 1} passed all tests, {SequenceMatcher(None, open(safe_compiler, "rb").read(), open(compiler_output, "rb").read()).real_quick_ratio() * 100:.2f}% similarity to previous file.')
    
    if i != 0:
        os.remove(safe_compiler)
    
    safe_compiler = compiler_output

print(f'{Fore.LIGHTGREEN_EX}Output file(s) passed all tests.')
move(compiler_output, f'new_stable.{platform_extension}')