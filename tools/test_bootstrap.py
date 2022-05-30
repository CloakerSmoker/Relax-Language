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
import argparse

# Uses stable_version.exe to compile the most recent version of the source, and then 
#  tests the new version of the compiled source (to ensure source changes haven't broken any part of the compiler)

# ONLY COMMIT AFTER A NEW VERSION PASSES THIS SCRIPT

init(autoreset=True)
cwd = os.getcwd()
path_join = os.path.join

bin_dir = path_join(cwd, 'build')
tools_dir = path_join(cwd, 'tools')

all_platforms = [('windows', 'exe'), ('linux', 'elf'), ('freebsd', 'elf')]

running_on = platform.system()

compile_command_format = '{} -i "./src/compiler/Main.rlx" -o "{}" --debug --' + running_on.lower()
platform_extension = 'exe'
python =  '"' + sys.executable + '"' if running_on == 'Windows' else sys.executable
expected_returncode = 1

if running_on == 'Linux' or running_on == 'FreeBSD':
    platform_extension = 'elf'
    expected_returncode = 0
elif running_on != 'Windows':
    print('Unsupported platform.', file=sys.stderr)
    sys.exit(1)

parser = argparse.ArgumentParser(description='Test lots of compiler builds')
parser.add_argument('iterations', type=int, nargs='?', default=3, help='number of times to have the compiler compile the compiler')
parser.add_argument('-r', '--release', action="store_true", help='should the output compilers replace the current/input compilers')
args = parser.parse_args()

recursion_count = args.iterations

if args.release:
	print('Building for release')

compile_command_format += ' ' + ' '.join(sys.argv[2:])

safe_compiler = path_join(bin_dir, f'{running_on.lower()}_compiler.{platform_extension}')

for i in range(0, recursion_count):
    compiler_output = path_join(bin_dir, f'testing{i}.{platform_extension}')
    compile_command = compile_command_format.format(safe_compiler, compiler_output)
	
    compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True)

    stderr_text = compile_result.stderr.decode('UTF-8')
    stdout_text = compile_result.stdout.decode('UTF-8')

    if compile_result.returncode != expected_returncode or len(stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}When running: {Fore.LIGHTWHITE_EX}{compile_command}')
        print(f'{Fore.LIGHTRED_EX}Compile error ({hex(compile_result.returncode)}):\n{stdout_text}\n\n{stderr_text}', file=sys.stderr)
        sys.exit(1)

    test_script = path_join(tools_dir, 'test_compiler.py')
    test_command = f'{python} {test_script} {compiler_output}'

    test_result = subprocess.run(test_command, cwd=cwd, shell=True, capture_output=True)
    stderr_text = test_result.stderr.decode('UTF-8')

    if len(stderr_text):
        print(f'{Fore.LIGHTRED_EX}Output file iteration {i + 1} failed 1+ test:\n{stderr_text}', file=sys.stderr)
        #os.remove(compiler_output)
        sys.exit(1)
    
    safe_bytes = open(safe_compiler, "rb").read()
    output_bytes = open(compiler_output, "rb").read()
    diff_count = len(output_bytes) - len(safe_bytes)
    diff = f'+{diff_count}' if diff_count >= 0 else str(diff_count)

    print(f'{Fore.LIGHTGREEN_EX}Output file iteration {i + 1} passed all tests, {SequenceMatcher(None, safe_bytes, output_bytes).real_quick_ratio() * 100:.2f}% similarity to previous file, {diff} bytes')
    
    if i != 0:
        os.remove(safe_compiler)
    
    safe_compiler = compiler_output

print(f'{Fore.LIGHTGREEN_EX}Output file(s) passed all tests.')

safe_compiler = path_join(bin_dir, f'safe_compiler.{platform_extension}')

move(compiler_output, safe_compiler)

for platform, extension in all_platforms:
    output = path_join(bin_dir, f'{platform}_new_compiler.{extension}')
    command = compile_command_format.format(safe_compiler, output) + ' --elf --debug --' + platform

    result = subprocess.run(command, cwd=cwd, shell=True, capture_output=True)
    stderr_text = result.stderr.decode('UTF-8')

    if result.returncode != expected_returncode or len(stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}{platform} compile error ({hex(result.returncode)}):\n{stderr_text}', file=sys.stderr)
        sys.exit(1)

    if args.release:
        move(output, path_join(bin_dir, f'{platform}_compiler.{extension}'))

    print(f'{Fore.LIGHTGREEN_EX}{platform} compile complete')
