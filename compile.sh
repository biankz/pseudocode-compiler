#!/bin/bash
rm -f lex.yy.c
rm -f $1.tab.c $1.tab.h
rm -f $1

bison -d $1.y
lex $1.l 
g++ -std=c++17 $1.tab.c lex.yy.c SymbolTable.cpp ASTNode.cpp -o $1
