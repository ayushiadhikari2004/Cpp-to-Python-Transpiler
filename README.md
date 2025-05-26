# C++ to Python Transpiler

A tool that converts C++ source code to equivalent Python code. This transpiler aims to help developers migrate their C++ codebase to Python by automating the translation process.

## Features

- Basic C++ syntax translation
- Variable declarations and assignments
- Basic control structures (if, while, for)
- Simple class definitions with member variables
- Standard input/output operations
- Basic arithmetic operations

## Limitations

Current version has some limitations:
- Limited support for complex class features:
  - Constructor definitions may not be properly translated
  - Method declarations might cause syntax errors
  - Inheritance is not fully supported
- No support for C++ templates
- Limited support for STL containers
- Some C++ specific features might not have direct Python equivalents

## Prerequisites

To build and run the transpiler, you need:
- GCC compiler
- Flex (Fast Lexical Analyzer)
- Bison (Parser Generator)
- Make utility

## Building the Transpiler

1. Clone the repository
2. Navigate to the Transpiler directory
3. Run make to build the project:
```bash
make clean
make
```

## Usage

The transpiler takes two arguments:
1. Input C++ source file
2. Output Python file name

```bash
./cpp2py input.cpp output.py
```

Example:
```bash
./cpp2py example.cpp example.py
```

## Example

Input C++ code:
```cpp
#include <iostream>
using namespace std;

class Simple {
    private:
        int value;
    
    public:
        void setValue(int v) {
            value = v;
        }

        int getValue() {
            return value;
        }
};

int main() {
    Simple obj;
    obj.setValue(42);
    cout << obj.getValue() << endl;
    return 0;
}
```

## Project Structure

- `parser.y`: Bison parser definition
- `scanner.l`: Flex lexical analyzer
- `ast.h/c`: Abstract Syntax Tree implementation
- `symtab.h/c`: Symbol table management
- `translation.h/c`: C++ to Python translation logic
- `utils.h/c`: Utility functions
- `Makefile`: Build configuration

## Contributing

Contributions are welcome! Here are some areas that need improvement:
1. Enhanced class support (constructors, methods, inheritance)
2. Better handling of C++ standard library features
3. Support for templates and generic programming
4. Improved error handling and reporting
5. More comprehensive test cases

## License

This project is open source and available under the MIT License.

## Known Issues

1. Class method declarations may cause syntax errors during transpilation
2. Complex C++ features might not be correctly translated
3. Some standard library functions might not have direct Python equivalents

## Future Work

- Implement full support for class features
- Add support for C++ templates
- Improve error handling and reporting
- Add support for more C++ standard library features
- Create a test suite for verification
- Add support for command-line options and configuration 