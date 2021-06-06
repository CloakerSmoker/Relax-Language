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

bin_dir = path_join(cwd, 'build')
tools_dir = path_join(cwd, 'tools')

running_on = platform.system()

compile_command_format = '{} -i "./src/compiler/Main.rlx" -o "{}" --debug'
platform_extension = 'exe'
python = sys.executable
expected_returncode = 1

if running_on == 'Linux':
    compile_command_format = f'{compile_command_format} --elf'
    platform_extension = 'elf'
    expected_returncode = 0
elif running_on != 'Windows':
    print('Unsupported platform.', file=sys.stderr)
    sys.exit(1)

recursion_count = 3

if len(sys.argv) >= 2:
    recursion_count = int(sys.argv[1])

compile_command_format += ' ' + ' '.join(sys.argv[2:])

safe_compiler = path_join(bin_dir, f'compiler.{platform_extension}')

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

safe_compiler = path_join(bin_dir, f'new_compiler.{platform_extension}')

move(compiler_output, safe_compiler)

if platform_extension == 'exe':
    elf_compile_output = path_join(bin_dir, 'new_compiler.elf')
    elf_compile_command = compile_command_format.format(safe_compiler, elf_compile_output) + ' --elf --debug'

    elf_compile_result = subprocess.run(elf_compile_command, cwd=cwd, shell=True, capture_output=True)

    elf_stderr_text = elf_compile_result.stderr.decode('UTF-8')

    if elf_compile_result.returncode != 1 or len(elf_stderr_text) != 0:
        print(f'{Fore.LIGHTRED_EX}ELF Compile error ({hex(elf_compile_result.returncode)}):\n{elf_stderr_text}', file=sys.stderr)
        sys.exit(1)
    
    print(f'{Fore.LIGHTGREEN_EX}ELF Compile complete.')
