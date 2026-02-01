#ifndef SYMBOLTABLE_HPP
#define SYMBOLTABLE_HPP

#include <string>
#include <vector>
#include <map>
#include <iostream>
#include <fstream>
using namespace std;

struct Symbol {
    string name;
    string type;
    string category;
    string value;
};

class SymbolTable {
public:
    string scopeName;
    SymbolTable* parent;
    map<string, Symbol> symbols;

    SymbolTable(string name, SymbolTable* p = nullptr);

    void insert(string name, string type, string category, string value = "");

    Symbol* findSymbol(const string& name);
    Symbol* findLocalSymbol(const string& name); //doar in scope ul curent

    static void addClass(const string& className, SymbolTable* scope);

    void print(ostream& out);
};


extern map<string, SymbolTable*> classScopes;
string checkFields(SymbolTable* scope, const string& field);
string checkMethods(SymbolTable* scope, SymbolTable* currentClassScope, const string& methodCall);
string typeOfLeftVal(SymbolTable* scope, const string& lv);
vector<string> splitByDots(const string& s);
Symbol* findClassMember(const string& className, const string& memberName);
vector<string> getParamTypes(const string& params);

#endif