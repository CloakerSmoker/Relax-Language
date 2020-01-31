# The Memory Module
You'll never guess what this one does.

## DllImports

| Imported Function Name | Imported Function Source |
|------------------------|--------------------------|
| GetProcessHeap         | GetProcessHeap, Kernel32 |
| HeapAlloc              | HeapAlloc, Kernel32      |
| HeapReAlloc            | HeapReAlloc, Kernel32    |
| HeapFree               | HeapFree, Kernel32       |

## Globals

| Full Global Name            | Default Value           |
|-----------------------------|-------------------------|
| i64 Memory:ProcessHeap      | Memory:GetProcessHeap() |
| i32 Memory:HEAP_ZERO_MEMORY | 0x00000008              |

## Functions

| Function Name | Return Type | Parameter List                | Description                                                                                 |
|---------------|-------------|-------------------------------|---------------------------------------------------------------------------------------------|
| Alloc         | `void*`     | `i64 Size`                    | Allocates `Size` bytes of memory on the heap, and returns a pointer to the allocated memory |
| ReAlloc       | `void*`     | `void* Memory`, `i64 NewSize` | Resizes `Memory` to `NewSize` and returns the new pointer to the memory                     |
| Free          | `i8`        | `void* Memory`                | Frees `Memory`                                                                              |

## Usage Impact

`Memory` does not import any other modules, and only takes ~150 bytes of the output file for imports + generated code.

`Memory` only exists so `GetProcessHeap` only needs to be called once.