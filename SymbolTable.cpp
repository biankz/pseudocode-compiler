#include "SymbolTable.hpp"
#include <sstream>
#include <vector>
#include <map>
using namespace std;

map<string, SymbolTable*> classScopes;

SymbolTable::SymbolTable(string name, SymbolTable* p): scopeName(name), parent(p) {}

void SymbolTable::insert(string name, string type, string category, string value) {
    symbols[name] = {name, type, category, value};
}

Symbol* SymbolTable::findLocalSymbol(const string& name) {
    auto it = symbols.find(name);
    if(it!=symbols.end()) return &it->second;
    return nullptr;
}

Symbol* SymbolTable::findSymbol(const string& name) {
    SymbolTable* scope = this;
    while(scope) {
        Symbol* result = scope->findLocalSymbol(name);
        if(result) return result;
        scope = scope->parent;
    }
    return nullptr;
}

void SymbolTable::addClass(const string& className, SymbolTable* scope) {
    classScopes[className] = scope;
}

void SymbolTable::print(ostream& out) {
    out << "Scope: " << scopeName << " | Parent: " << (parent ? parent->scopeName : "None") << "\n";
    out << "----------------------------------------------------------\n";
    for (auto const& [name, sym] : symbols) {
        if (sym.category == "variable") {
            out << "Name: " << sym.name << " | Type: " << sym.type
                << " | Category: " << sym.category << " | Value: " << sym.value << "\n";
        } else if (sym.category == "class") {
            out << "Name: " << sym.name << " | Category: " << sym.category << "\n";
        } else if (sym.category == "function") {
            out << "Name: " << sym.name << " | Type: " << sym.type
                << " | Category: " << sym.category << " | Parameters: " << sym.value << "\n";
        } else if (sym.category == "parameter") {
            out << "Name: " << sym.name << " | Type: " << sym.type
                << " | Category: " << sym.category << "\n";
        }
    }
    out << "\n";
}

// ---------------- helpers ----------------------

vector<string> splitByDots(const string& str) {
    vector<string> parts;
    stringstream ss(str);
    string part;
    while(getline(ss, part, '.'))
        parts.push_back(part);
    return parts;
}

Symbol* findClassMember(const string& className, const string& memberName) {
    auto it = classScopes.find(className);
    if(it==classScopes.end()) return nullptr;
    return it->second->findLocalSymbol(memberName);
}

string checkFields(SymbolTable* scope, const string& field) {
    auto parts = splitByDots(field);
    if(parts.empty()) return "";

    Symbol* id = scope->findSymbol(parts[0]);
    if(!id) return "Eroare: identificatorul " + parts[0] + " nu a fost declarat.\n";

    string currentType = id->type;

    for(int i=1; i < parts.size(); ++i) {
        if(classScopes.find(currentType) == classScopes.end())
            return "Eroare: " + parts[i-1] + " nu este instanta a unei clase.\n";
        Symbol* member = findClassMember(currentType, parts[i]);
        if(!member) return "Eroare: " + parts[i] + " nu exista in clasa " + currentType + ".\n"; 
        currentType = member->type;
    }
    return currentType;
}

string checkMethods(SymbolTable* scope, SymbolTable* currentClassScope, const string& methodCall) {
    auto parts = splitByDots(methodCall);
    if(parts.size() == 1) {
        const string& name = parts[0];
        if (!currentClassScope) {
            return "ok";
        }
        Symbol* member = currentClassScope->findLocalSymbol(name);
        if (member && member->category == "function") return "ok";
        return "Eroare: '" + name + "' nu este metoda a clasei curente.\n";

    }

    string prefix;
    for (int i=0; i < parts.size() - 1; ++i) {
        if(i) prefix += ".";
        prefix += parts[i];
    }

    string prefixType = checkFields(scope, prefix);
    if (prefixType.rfind("Eroare: ", 0) == 0) return prefixType;

    Symbol* member = findClassMember(prefixType, parts.back());
    if(!member) return "Eroare: " + parts.back() + " nu este o metoda in clasa " + prefixType + ".\n";
    if(member->category!="function") return "Eroare: " + parts.back() + " exista in clasa " + prefixType +", dar nu este metoda.\n";

    return "ok";
}

string typeOfLeftVal(SymbolTable* scope, const string& field) {
    if(field.find('.') != string::npos) {
        string t = checkFields(scope, field);
        if(t.rfind("Eroare: ", 0) == 0)
            return "error";
        return t;
    }
    Symbol* s = scope->findSymbol(field);
    if(!s) return "error";
    return s->type;
}

vector<string> getParamTypes(const string& params) {
    vector<string> types;
    stringstream ss(params);
    string part;

    auto trim = [](string& x) {
        while (!x.empty() && isspace((unsigned char)x.front())) x.erase(x.begin());
        while (!x.empty() && isspace((unsigned char)x.back())) x.pop_back();
    };

    while (std::getline(ss, part, ',')) {
        trim(part);
        if (part.empty()) continue;
        stringstream ps(part);
        string type;
        ps >> type;
        if (!type.empty()) 
            types.push_back(type);
    }
    return types;
}