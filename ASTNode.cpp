#include "ASTNode.hpp"
#include <iostream>
using namespace std;

extern void yyerror(const char *s);

Value ASTNode::eval(SymbolTable* table) {
    if (label == "INT")    { 
        inferredType = Value::Type::INT;    
        return Value(Value::Type::INT, text); 
    }
    if (label == "FLOAT")  { 
        inferredType = Value::Type::FLOAT;  
        return Value(Value::Type::FLOAT, text); 
    }
    if (label == "BOOL")   { 
        inferredType = Value::Type::BOOL;   
        return Value(Value::Type::BOOL, text); 
    }
    if (label == "STRING") { 
        inferredType = Value::Type::STRING; 
        return Value(Value::Type::STRING, text); 
    }

    if (label == "ID") {
        Symbol* s = (table ? table->findSymbol(text) : nullptr);
        if (!s) {
            yyerror(("Eroare: variabila " + text + " nedeclarata\n").c_str());
            inferredType = Value::Type::DEFAULT;
            return Value();
        }

        Value::Type t = Value::Type::DEFAULT;
        if (s->type == "int") t = Value::Type::INT;
        else if (s->type == "float") t = Value::Type::FLOAT;
        else if (s->type == "bool") t = Value::Type::BOOL;
        else if (s->type == "string") t = Value::Type::STRING;

        inferredType = t;
        return Value(t, s->value);
    }

    if (label == "OTHER") {
        inferredType = Value::Type::DEFAULT;
        return Value();
    }

    if (label == ":=") {
        if (!left || !right || left->label != "ID") {
            yyerror("Eroare: asignare invalida\n");
            inferredType = Value::Type::DEFAULT;
            return Value();
        }

        Value v = right->eval(table);

        Symbol* s = (table ? table->findSymbol(left->text) : nullptr);
        if (!s) {
            yyerror(("Eroare: asignare la variabila nedeclarata " + left->text + "\n").c_str());
            inferredType = Value::Type::DEFAULT;
            return Value();
        }

        s->value = v.toString();
        inferredType = v.type;
        return v;
    }

    if (label == "Print") {
        if (!left) {
            yyerror("Eroare: Print fara expresie\n");
            inferredType = Value::Type::DEFAULT;
            return Value();
        }
        Value v = left->eval(table);
        v.print();
        cout << "\n";
        inferredType = v.type;
        return v;
    }

    if (label == "!") {
        if (!left) { inferredType = Value::Type::DEFAULT; return Value(); }
        Value v = left->eval(table);
        bool res = !v.asBool();
        inferredType = Value::Type::BOOL;
        return Value(Value::Type::BOOL, res ? "true" : "false");
    }

    if (label == "&&" || label == "||") {
        if (!left || !right) { inferredType = Value::Type::DEFAULT; return Value(); }
        Value l = left->eval(table);
        Value r = right->eval(table);
        bool result = (label == "&&") ? (l.asBool() && r.asBool()) : (l.asBool() || r.asBool());
        inferredType = Value::Type::BOOL;
        return Value(Value::Type::BOOL, result ? "true" : "false");
    }

    if (label == "+" || label == "-" || label == "*" || label == "/") {
        if (!left || !right) { inferredType = Value::Type::DEFAULT; return Value(); }
        Value l = left->eval(table);
        Value r = right->eval(table);

        // opțional: concatenare string cu +
        if (label == "+" && (l.type == Value::Type::STRING || r.type == Value::Type::STRING)) {
            inferredType = Value::Type::STRING;
            return Value(Value::Type::STRING, l.toString() + r.toString());
        }

        bool useFloat = (l.type == Value::Type::FLOAT || r.type == Value::Type::FLOAT);

        if (useFloat) {
            float a = (l.type == Value::Type::FLOAT) ? l.asFloat() : (float)l.asInt();
            float b = (r.type == Value::Type::FLOAT) ? r.asFloat() : (float)r.asInt();

            if (label == "/" && b == 0.0f) {
                yyerror("Eroare: impartire la 0\n");
                inferredType = Value::Type::DEFAULT;
                return Value();
            }

            float res = 0.0f;
            if (label == "+") res = a + b;
            else if (label == "-") res = a - b;
            else if (label == "*") res = a * b;
            else if (label == "/") res = a / b;

            inferredType = Value::Type::FLOAT;
            return Value(Value::Type::FLOAT, to_string(res));
        } else {
            int a = l.asInt();
            int b = r.asInt();

            if (label == "/" && b == 0) {
                yyerror("Eroare: impartire la 0\n");
                inferredType = Value::Type::DEFAULT;
                return Value();
            }

            int res = 0;
            if (label == "+") res = a + b;
            else if (label == "-") res = a - b;
            else if (label == "*") res = a * b;
            else if (label == "/") res = a / b;

            inferredType = Value::Type::INT;
            return Value(Value::Type::INT, to_string(res));
        }
    }

    if (label == "<" || label == ">" || label == "<=" || label == ">=" || label == "==" || label == "!=") {
        if (!left || !right) { inferredType = Value::Type::DEFAULT; return Value(); }

        Value l = left->eval(table);
        Value r = right->eval(table);

        bool result = false;

        if (label == "==" || label == "!=") {
            if (l.type == Value::Type::STRING && r.type == Value::Type::STRING) {
                result = (l.toString() == r.toString());
            } else if (l.type == Value::Type::BOOL && r.type == Value::Type::BOOL) {
                result = (l.asBool() == r.asBool());
            } else {
                float a = (l.type == Value::Type::FLOAT) ? l.asFloat() : (float)l.asInt();
                float b = (r.type == Value::Type::FLOAT) ? r.asFloat() : (float)r.asInt();
                result = (a == b);
            }
            if (label == "!=") result = !result;
            inferredType = Value::Type::BOOL;
            return Value(Value::Type::BOOL, result ? "true" : "false");
        }

        float a = (l.type == Value::Type::FLOAT) ? l.asFloat() : (float)l.asInt();
        float b = (r.type == Value::Type::FLOAT) ? r.asFloat() : (float)r.asInt();

        if (label == "<") result = a < b;
        else if (label == "<=") result = a <= b;
        else if (label == ">") result = a > b;
        else if (label == ">=") result = a >= b;

        inferredType = Value::Type::BOOL;
        return Value(Value::Type::BOOL, result ? "true" : "false");
    }

    inferredType = Value::Type::DEFAULT;
    return Value();
}