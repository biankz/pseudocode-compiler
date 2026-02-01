#pragma once
#include <string>
#include <iostream>
using namespace std;

class Value {
public:
    enum class Type { 
        INT, 
        FLOAT, 
        BOOL, 
        STRING, 
        DEFAULT 
    };

    Type type;
    string raw;   

    Value(): type(Type::DEFAULT), raw("") {}
    Value(Type t, const string& v): type(t), raw(v) {}

    int asInt() const {
        try {
            if (type == Type::BOOL) return asBool() ? 1 : 0;
            return std::stoi(raw);
        } catch (...) { return 0; }
    }

    float asFloat() const {
        try {
            if (type == Type::BOOL) return asBool() ? 1.0f : 0.0f;
            return std::stof(raw);
        } catch (...) { return 0.0f; }
    }

    bool asBool() const {
        if (type == Type::INT) return asInt() != 0;
        if (type == Type::FLOAT) return asFloat() != 0.0f;
        return raw == "true" || raw == "1";
    }

    string toString() const {
        return raw;
    }

    void print() const {
        if(type == Type::BOOL)
            cout << (asBool() ? "true" : "false");
        else
            cout << raw;
    }
};
