import sys
import os
import os.path as path
import subprocess
import platform
import time
from shutil import copyfile
from shutil import rmtree
from shutil import move
from colorama import init, Fore, Back, Style

# Tests if argv[1] is capable of (correctly) compiling all of the test programs
#  by compiling each test with argv[1], running the output files, and checking the 
#   outputs against known-correct outputs

init(autoreset=True)
path_join = os.path.join
argv = sys.argv

running_on = platform.system()

compile_command_format = '{} -i "{}" -o "{}'
platform_extension = 'exe'
run_command_format = '{}.{} {}'
expected_exitcode = 1

if running_on == 'Linux' or running_on == 'FreeBSD':
    compile_command_format = f'{compile_command_format}.elf" --elf --debug --' + running_on.lower()
    platform_extension = 'elf'
    run_command_format = f'{run_command_format}'
    expected_exitcode = 0
elif running_on == 'Windows':
    compile_command_format += '.exe" --pe --debug'
else:
    print('Unsupported platform.', file=sys.stderr)
    sys.exit(1)

if len(argv) != 2:
    print('Expected path to compiler executable to test.')
    sys.exit(1)

compiler_path = path.abspath(argv[1])
cwd = os.getcwd()

tests_dir = path_join(cwd, 'tests')
build_dir = path_join(cwd, 'build')

for test_path in os.listdir(tests_dir):
    path_parts = path.split(test_path)
    name_parts = path.splitext(path_parts[1])
    file_name = name_parts[0]
    file_ext = name_parts[1]

    if file_ext != '.rlx':
        continue
    
    inputs_outputs_path = path_join(tests_dir, f'{file_name}_tests.txt')
    
    with open(inputs_outputs_path, mode='r') as f:
        inputs_outputs = [line.split(':') for line in f.read().splitlines()]

    source_file = path_join(tests_dir, f'{file_name}.rlx')
    binary_file = path_join(build_dir, f'{file_name}')
    compile_command = compile_command_format.format(compiler_path, source_file, binary_file)
    #f'{compiler_path} -i "{source_file}" -o "{binary_file}" {compiler_extra}'

    # Compiler is ran in the main/current dir so `#Include` can use regular paths
    compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True, timeout=1)
    stderr_text = compile_result.stderr.decode('UTF-8')
    no_stderr = len(stderr_text) == 0
    
    if compile_result.returncode != expected_exitcode or not no_stderr:
        stdout_text = compile_result.stdout.decode('UTF-8')
		
        if no_stderr:
            stderr_text = 'no stderr.'
        else:
            stderr_text = f'stderr "{stderr_text}".'
        
        stderr_text += f'\nstdout:\n{stdout_text}'
        
        print(f'{Fore.RED}Test {file_name} failed to compile with exit code {hex(compile_result.returncode)} and {stderr_text}', file=sys.stderr)
        continue

    test_number = 1
    tests_passed = 0

    for test_input, test_output in inputs_outputs:
        test_run_command = run_command_format.format(binary_file, platform_extension, test_input.strip())
        #f'{binary_file} {test_input.strip()}'

        test_result = subprocess.run(test_run_command, cwd=tests_dir, shell=True, capture_output=True, timeout=1)
        stdout_text = test_result.stdout.decode('UTF-8')
        stderr_text = test_result.stderr.decode('UTF-8')

        if test_result.returncode != 0 or len(stderr_text) != 0:
            if stderr_text:
                stderr_text = 'and stderr ' + stderr_text
            
            print(f'    {Fore.RED}Test {file_name}[{test_number}] failed to run with exit code {hex(test_result.returncode)} {stderr_text}', file=sys.stderr)
        elif stdout_text != test_output:
            print(f'    {Fore.RED}Test {file_name}[{test_number}] failed to produce correct output, expected {test_output}, got {stdout_text}', file=sys.stderr)
        else:
            tests_passed += 1
        
        test_number += 1

    test_count = len(inputs_outputs)
    foreground = Fore.LIGHTRED_EX

    if tests_passed == test_count:
        try:
            os.remove(f'{binary_file}.{platform_extension}')
        except:
            pass
        foreground = Fore.LIGHTGREEN_EX

    print(f'Test {file_name} {foreground}{tests_passed}/{len(inputs_outputs)}{Fore.WHITE} passed.')
