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

from tap.parser import Parser as TAPParser

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

platform_extension = 'exe'
python =  '"' + sys.executable + '"' if running_on == 'Windows' else sys.executable
expected_returncode = 1

if running_on == 'Linux' or running_on == 'FreeBSD':
    platform_extension = 'elf'
    expected_returncode = 0
elif running_on != 'Windows':
    print('Unsupported platform.', file=sys.stderr)
    sys.exit(1)

compiler_link = f'build/{running_on.lower()}_test_compiler.{platform_extension}'
compile_command_format = compiler_link + ' -i "./src/compiler/Main.rlx" -o "{}" --debug --' + running_on.lower()

if 'RLXFLAGS' in os.environ:
    compile_command_format = f'{compile_command_format} {os.environ["RLXFLAGS"]}'

def use_compiler(new):
    try:
        os.unlink(compiler_link)
    except:
        pass

    os.link(new, compiler_link)

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

    use_compiler(safe_compiler)
    compile_command = compile_command_format.format(compiler_output)
	
    compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True)

    stderr_text = compile_result.stderr.decode('UTF-8')
    stdout_text = compile_result.stdout.decode('UTF-8')

    if compile_result.returncode != expected_returncode or len(stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}When running: {Fore.LIGHTWHITE_EX}{compile_command.replace(compiler_link, safe_compiler)}')
        print(f'{Fore.LIGHTRED_EX}Compile error ({hex(compile_result.returncode)}):\n{stdout_text}\n\n{stderr_text}', file=sys.stderr)
        sys.exit(1)

    use_compiler(compiler_output)
    test_command = f'{python} -m turnt -j -e {running_on.lower()} tests/*.rlx'

    test_result = subprocess.run(test_command, cwd=cwd, shell=True, capture_output=True, env={**os.environ, 'RLX': compiler_output})
    
    stdout_text = test_result.stdout.decode('UTF-8')

    p = TAPParser()

    fails = []
    passes = []
    
    for line in p.parse_text(stdout_text):
        if line.category == 'test':
            if line.ok:
                passes.append(line)
            else:
                fails.append(line)
    
    if len(fails) != 0:
        print(f'{Fore.LIGHTRED_EX}While testing: {Fore.LIGHTWHITE_EX}{compile_command}{Fore.RESET}')

        print(f'{Fore.LIGHTRED_EX}{len(passes)} / {len(passes) + len(fails)}{Fore.RESET} tests passed')

        for fail in fails:
            print(f'{Fore.LIGHTRED_EX}{fail.number} {fail.description}{Fore.RESET} failed')
            
            fail_file = fail.description[2:-len(running_on)-1]
            compiler_rel = os.path.relpath(compiler_output, os.getcwd())

            print(f'{Fore.LIGHTMAGENTA_EX}turnt -e {running_on.lower()} {fail_file} -p{Fore.RESET}')
    
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
    use_compiler(safe_compiler)
    command = compile_command_format.format(output) + ' --elf --debug --' + platform

    result = subprocess.run(command, cwd=cwd, shell=True, capture_output=True)
    stderr_text = result.stderr.decode('UTF-8')

    if result.returncode != expected_returncode or len(stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}{platform} compile error ({hex(result.returncode)}):\n{stderr_text}', file=sys.stderr)
        sys.exit(1)

    if args.release:
        copyfile(output, path_join(bin_dir, f'{platform}_compiler.{extension}'))

    print(f'{Fore.LIGHTGREEN_EX}{platform} compile complete')
