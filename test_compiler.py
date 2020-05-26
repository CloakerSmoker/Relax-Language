import sys
import os
import os.path as path
import subprocess
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

if len(argv) != 2:
    print('Expected path to compiler executable to test.')
    sys.exit(1)

compiler_path = path.abspath(argv[1])
cwd = os.getcwd()

tests_dir = path_join(cwd, 'tests')

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
    binary_file = path_join(tests_dir, f'{file_name}.exe')
    compile_command = f'{compiler_path} -i "{source_file}" -o "{binary_file}"'

    # Compiler is ran in the main/current dir so `#Include` can use regular paths
    compile_result = subprocess.run(compile_command, cwd=cwd, shell=True, capture_output=True)
    stderr_text = compile_result.stderr.decode('UTF-8')

    if compile_result.returncode != 1 or len(stderr_text) != 0:
        print(f'{Fore.RED}Test {file_name} failed to compile with exit code {hex(compile_result.returncode)} and stderr "{stderr_text}""', file=sys.stderr)
        continue

    test_number = 1
    tests_passed = 0

    for test_input, test_output in inputs_outputs:
        test_run_command = f'{binary_file} {test_input.strip()}'

        test_result = subprocess.run(test_run_command, cwd=tests_dir, shell=True, capture_output=True)
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

    os.remove(binary_file)
    
    test_count = len(inputs_outputs)
    foreground = Fore.LIGHTRED_EX

    if tests_passed == test_count:
        foreground = Fore.LIGHTGREEN_EX

    print(f'Test {file_name} {foreground}{tests_passed}/{len(inputs_outputs)}{Fore.WHITE} passed.')