#pragma once
#include <string>
#include <memory>
#include "Value.hpp"
#include "SymbolTable.hpp"
using namespace std;

class ASTNode {
public:
    string label;
    string text;
    shared_ptr<ASTNode> left;
    shared_ptr<ASTNode> right;
    Value::Type inferredType = Value::Type::DEFAULT;

    ASTNode(const string& lbl): label(lbl) {}

    ASTNode(const string& lbl, const string& txt): label(lbl), text(txt) {}

    Value eval(SymbolTable* table);
};
