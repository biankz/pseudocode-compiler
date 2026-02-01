# Pseudocode Compiler

A toy compiler for a pseudocode-like programming language, implemented in **C++** using **Flex** and **Bison**.

The project performs lexical analysis, parsing, semantic analysis, and runtime evaluation of programs written in a language inspired by pseudocode.

---

## Language Features
- Variable declarations using `let`
- Primitive data types:
  - `int`
  - `float`
  - `bool`
  - `string`
- Arithmetic and logical expressions
- Control flow:
  - `if / then / else`
  - `while`
  - `for`
- Functions with parameters and return values
- Class definitions with access modifiers
- Built-in `Print` statement

---

## Implementation Details

### Lexical & Syntax Analysis
- Implemented using **Flex** (`limbaj.l`) and **Bison** (`limbaj.y`)
- Supports structured programs with `begin / end`
- Detailed syntax and semantic error reporting with line numbers

### Abstract Syntax Tree (AST)
- Each expression and statement is represented as an `ASTNode`
- AST nodes are evaluated recursively at runtime
- Type inference is performed during evaluation

### Symbol Table & Scoping
- Hierarchical symbol table implementation
- Supports:
  - nested scopes
  - function scopes
  - class scopes
- Detects semantic errors such as:
  - use of undeclared variables
  - invalid assignments
  - incorrect type usage

### Runtime Evaluation
- Programs are executed directly by evaluating the AST
- No intermediate code or binary generation
- Values are handled dynamically via a unified `Value` abstraction

---

## Project Structure
```text
.
├── ASTNode.hpp / ASTNode.cpp # AST representation and evaluation logic
├── SymbolTable.hpp / SymbolTable.cpp # Symbol table and scope management
├── Value.hpp # Runtime value abstraction
├── limbaj.l # Lexer (Flex)
├── limbaj.y # Parser and semantic rules (Bison)
├── compile.sh # Build script
└── README.md
```
---

## Build & Run

### Requirements
- `g++` (C++17)
- `flex`
- `bison`

### Compile
```bash
chmod +x compile.sh
./compile.sh limbaj
./limbaj program.txt
