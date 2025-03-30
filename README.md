# C@ (catlang) 🐈

### Description
A personal exercise in writing an optimizing compiler and language
design.  
The language is called C@ (as in C at, cat), or catlang, and this repo serves as the reference compiler implementation written in Zig.  
The main goals of the language are: **LLVM-free** x86 and ARM64 codegen, **static typing** and a standard library that includes easy to use graphic primitives and drawing to a window, to make it easy to write good native apps that dont use electron or a webview.

### TODO
- **Frontend**  
  - [x] Tokenization  
  - [x] Parsing (AST)  
  - [ ] Type Checking
- **Backend**  
  - [ ] IR Design
  - [ ] ARM64 Codegen  
  - [ ] x86 Codegen
