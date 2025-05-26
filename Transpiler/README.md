# C++ to Python Transpiler

A transpiler that converts C++ code to equivalent Python code.

## Features

- Converts basic C++ syntax to Python
- Handles class definitions and inheritance
- Supports basic control structures (if, else, for loops)
- Manages variable declarations and type conversions
- Handles function definitions and calls

## Prerequisites

- GCC compiler
- Flex (Fast Lexical Analyzer)
- Bison (Parser Generator)
- Make

## Building

To build the transpiler:

```bash
make clean
make
```

## Usage

To convert a C++ file to Python:

```bash
./cpp2py input.cpp output.py
```

## Project Structure

- `scanner.l`: Lexical analyzer definitions
- `parser.y`: Grammar rules and parsing logic
- `ast.h/c`: Abstract Syntax Tree implementation
- `symtab.h/c`: Symbol table management
- `translation.h/c`: Code generation and translation logic
- `utils.h/c`: Utility functions

## License

This project is open source and available under the MIT License. 