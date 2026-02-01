%code requires {
   #include <string>
   #include <vector>
   using namespace std;

   class ASTNode;

    struct ExprAst {
        string type;
        string value;
        ASTNode* ast;
    };
 }

%{
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <fstream>
#include <sstream>
#include "SymbolTable.hpp"
#include "ASTNode.hpp"

extern FILE* yyin;
extern char* yytext;
extern int yylineno;
extern int yylex();
void yyerror(const char * s);
int errorCount = 0;

SymbolTable* globalScope = new SymbolTable("global");
SymbolTable* currentScope = globalScope;
std::vector<SymbolTable*> allTables = { globalScope };
std::string lastType;
std::string currentParams;  
bool inStatementBlock = false;
SymbolTable* currentClassScope = nullptr;

%}

%union{
    std::string* Str;
    int Int;
    double Float;
    char Char;
    std::vector<std::string>* TypeList;
    ExprAst* expr;
    std::vector<ExprAst>* ExprList;
    ASTNode* node;
}

%token <Str>   ID
%token <Int>   INT_LITERAL
%token <Float> FLOAT_LITERAL
%token <Str>   STRING_LITERAL
%token <Char>  CHAR_LITERAL

%token T_BEGIN T_END PROGRAM
%token IF THEN ELSE
%token WHILE DO
%token FOR
%token RETURN ARROW FN
%token CLASS NEW
%token PRINT
%token TYPE_INT TYPE_FLOAT TYPE_STRING TYPE_CHAR TYPE_BOOL TYPE_VOID
%token BOOL_TRUE BOOL_FALSE
%token ASSIGN DOT
%token OP_EQ OP_NE OP_LE OP_GE
%token OP_AND OP_OR OP_NOT
%token PUBLIC PRIVATE PROTECTED
%token LET

%type <expr> expr arithmetic_expr boolean_expr new_expr call_expr primary boolean_primary
%type <node> main_statement_line simple_statement assign_statement print_statement if_statement while_statement for_statement
%type <Str> leftval comp
%type <ExprList> arg_list arg_list_nonempty

%left OP_OR
%left OP_AND
%right OP_NOT
%left OP_EQ OP_NE
%left '<' '>' OP_LE OP_GE
%left '+' '-'
%left '*' '/' '%'
%right UMINUS

%start program
%%

program : declarations main ;

declarations : /* gol */ | declarations decl;

decl : var_decl ';' | function_decl | class_decl | assign_statement ';';

main : T_BEGIN PROGRAM statement_list T_END PROGRAM;

function_decl : FN ID {
                    SymbolTable* fnScope = new SymbolTable(*$2, currentScope);
                    allTables.push_back(fnScope);
                    currentScope = fnScope;
                    currentParams = "";
                }
                '(' list_param ')' return_type {
                    std::string params = currentParams;
                    if (!params.empty()) params = params.substr(0, params.size() - 2);

                    if (currentScope->parent->findLocalSymbol(*$2))
                        yyerror(("Eroare: functia " + *$2 + " este deja declarata in acest scope.\n").c_str());
                    else 
                        currentScope->parent->insert(*$2, lastType, "function", params);
                }
                function_list
                T_END FN {
                    currentScope = currentScope->parent;
                    delete $2;
                };

list_param : /* gol */ | list_param_nonempty;

list_param_nonempty: type ID {
                        if (currentScope->findLocalSymbol(*$2)) {
                            yyerror(("Eroare: parametrul " + *$2 + " este deja declarat in acest scope.\n").c_str());
                        } else {
                            currentParams += lastType + " " + *$2 + ", ";
                            currentScope->insert(*$2, lastType, "parameter");
                        }
                        delete $2;
                    }
                    | list_param_nonempty ',' type ID {
                        if (currentScope->findLocalSymbol(*$4)) {
                            yyerror(("Eroare: parametrul " + *$4 + " este deja declarat in acest scope.\n").c_str());
                        } else {
                            currentParams += lastType + " " + *$4 + ", ";
                            currentScope->insert(*$4, lastType, "parameter");
                        }
                        delete $4;
                    };

type : TYPE_INT    { lastType = "int"; }
      | TYPE_FLOAT  { lastType = "float"; }
      | TYPE_STRING { lastType = "string"; }
      | TYPE_CHAR   { lastType = "char"; }
      | TYPE_BOOL   { lastType = "bool"; }
      | TYPE_VOID   { lastType = "void"; }
      | ID { 
                Symbol* s = currentScope->findSymbol(*$1);
                if (!s || s->category != "class") 
                    yyerror(("Eroare: tipul " + *$1 + " nu este o clasa declarata.\n").c_str());
                lastType = *$1; 
                delete $1; 
            };

return_type : /* gol */ { lastType = "void"; } | ARROW type ;

id_list : ID {
             if(inStatementBlock) {
                 yyerror("Eroare: Declararea variabilelor in blocuri if/while este interzisa!");
             } else {
                 if (currentScope->findLocalSymbol(*$1))
                     yyerror(("Eroare: " + *$1 + " este deja declarat in acest scope.\n").c_str());
                 else
                     currentScope->insert(*$1, lastType, "variable");
             }
             delete $1;
         }
         | id_list ',' ID {
             if(inStatementBlock) {
                 yyerror("Eroare: Declararea variabilelor in blocuri if/while este interzisa!");
             } else {
                 if (currentScope->findLocalSymbol(*$3))
                     yyerror(("Eroare: " + *$3 + " este deja declarat in acest scope.\n").c_str());
                 else
                     currentScope->insert(*$3, lastType, "variable");
             }
             delete $3;
         };

class_decl : CLASS ID {
                if (currentScope->findLocalSymbol(*$2)) 
                    yyerror(("Eroare: clasa " + *$2 + " este deja declarata in acest scope.\n").c_str());
                else
                    currentScope->insert(*$2, "class", "class");

                SymbolTable* clScope = new SymbolTable(*$2, currentScope);
                allTables.push_back(clScope);
                currentScope = clScope;

                SymbolTable::addClass(*$2, clScope);
                currentClassScope = clScope;
             }
             class_content 
             T_END CLASS {
                currentScope = currentScope->parent; 
                currentClassScope = nullptr;
                delete $2;
             };

class_content : /* gol */ | class_content class_section;

class_section : access_specifier ':' class_member_list;

access_specifier : PUBLIC | PRIVATE | PROTECTED;

class_member_list : /* gol */ | class_member_list class_member ';';

class_member : function_decl | class_var_decl;

statement_list : /* gol */ | statement_list main_statement_line;

main_statement_line : simple_statement ';' {
                        if ($1) {
                            $1->eval(globalScope);
                            delete $1;
                        }
                    }
                    | compound_statement { $$ = nullptr; };

function_list : /* gol */ | function_list function_statement_line;

function_statement_line : simple_statement ';' | var_decl ';' | compound_statement;

simple_statement : assign_statement { $$ = $1; } 
                | print_statement { $$ = $1; }
                | return_statement { $$ = nullptr; }
                | call_expr {
                    delete $1;
                    $$ = nullptr;
                };

compound_statement : if_statement | while_statement | for_statement;

var_decl : LET type id_list
           | LET type ID ASSIGN expr {
                  if(inStatementBlock) {
                      yyerror("Eroare: Declararea variabilelor in blocuri if/while este interzisa!");
                  } else {
                      if (currentScope->findLocalSymbol(*$3))
                          yyerror(("Eroare: " + *$3 + " este deja declarat in acest scope.\n").c_str());
                      else
                          currentScope->insert(*$3, lastType, "variable", $5->value);
                  }
                  delete $3; delete $5;
             };

class_var_decl : LET type ID {
                     if (currentScope->findLocalSymbol(*$3))
                         yyerror(("Eroare: " + *$3 + " este deja declarat in acest scope.\n").c_str());
                     else
                         currentScope->insert(*$3, lastType, "variable");
                     delete $3;
                }
               | LET type ID ASSIGN expr {
                     if (currentScope->findLocalSymbol(*$3))
                         yyerror(("Eroare: " + *$3 + " este deja declarat in acest scope.\n").c_str());
                     else
                         currentScope->insert(*$3, lastType, "variable", $5->value);
                     delete $3; delete $5;
                }
               | type ID {
                     if (currentScope->findLocalSymbol(*$2))
                         yyerror(("Eroare: " + *$2 + " este deja declarat in acest scope.\n").c_str());
                     else
                         currentScope->insert(*$2, lastType, "variable");
                     delete $2;
                }
               | type ID ASSIGN expr {
                     if (currentScope->findLocalSymbol(*$2))
                         yyerror(("Eroare: " + *$2 + " este deja declarat in acest scope.\n").c_str());
                     else
                         currentScope->insert(*$2, lastType, "variable", $4->value);
                     delete $2; delete $4;
                };

if_statement : IF boolean_expr THEN { inStatementBlock = true; }
                  statement_list
               else_statement
               T_END IF { inStatementBlock = false; };

else_statement : /* gol */ | ELSE statement_list;

while_statement : WHILE boolean_expr DO { inStatementBlock = true; }
                    statement_list
                  T_END WHILE { inStatementBlock = false; };

for_statement : FOR ID ASSIGN arithmetic_expr ','  arithmetic_expr ',' arithmetic_expr DO
                  statement_list
                T_END FOR { delete $2; };

assign_statement : leftval ASSIGN expr {
                        std::string leftType = typeOfLeftVal(currentScope, *$1);
                        std::string rightType = $3->type;
                        if(leftType != rightType && leftType != "error" && rightType != "error")
                            yyerror(("Eroare: incompatibilitate de tip la asignare (" + leftType + " = " + rightType + ").\n").c_str());

                        if($1->find('.') == std::string::npos) {
                            ASTNode* root = new ASTNode(":=");
                            root->left  = std::shared_ptr<ASTNode>(new ASTNode("ID", *$1));
                            root->right = std::shared_ptr<ASTNode>($3->ast);
                            $$ = root;
                        } 
                        else $$ = nullptr;
                        delete $1;
                        delete $3;
                    };

leftval : ID { 
                if(!currentScope->findSymbol(*$1)) {
                    yyerror(("Eroare: identificatorul " + *$1 + " nu este declarat.\n").c_str());
                    delete $1;
                    $$ = new std::string("error");
                }
                else $$ = $1;
            } 
        | leftval DOT ID { 
                std::string composed = *$1 + "." + *$3;
                std::string result = checkFields(currentScope, composed);
                if (result.rfind("Eroare: ", 0) == 0) {
                    yyerror(result.c_str());
                    $$ = new std::string("error");
                }
                else $$ = new std::string(composed); 
                delete $1; 
                delete $3; 
            };

print_statement : PRINT '(' expr ')' {
        ASTNode* root = new ASTNode("Print");
        root->left = std::shared_ptr<ASTNode>($3->ast);
        $$ = root;
        delete $3;
    };

return_statement : RETURN | RETURN expr;

call_expr : leftval '(' arg_list ')' {
        if(checkMethods(currentScope, currentClassScope, *$1) != "ok") {
            yyerror(checkMethods(currentScope, currentClassScope, *$1).c_str());
            $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
        }
        else {
            Symbol* f = currentScope->findSymbol(*$1);
            if(!f) { // compus
                auto parts = splitByDots(*$1);
                std::string prefix;
                for(int i = 0; i < parts.size()-1; ++i) {
                    if(i) prefix += ".";
                    prefix+=parts[i];
                }
                std::string prefixType = checkFields(currentScope, prefix);
                if (prefixType.rfind("Eroare: ", 0) == 0) {
                    $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                }
                else {
                    f = findClassMember(prefixType, parts.back());
                    if(!f) {
                        yyerror("Eroare: nu pot determina functia/metoda apelata.\n");
                        $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                    }
                }
            }

            if(f) {
                std::vector<std::string> expected = getParamTypes(f->value);
                std::vector<std::string> actual;
                for(auto& e : *$3) actual.push_back(e.type);

                if (expected.size() != actual.size())
                    yyerror(("Eroare: numar parametri diferit. Asteptat " + std::to_string(expected.size()) + ", primit " + std::to_string(actual.size()) + ".\n").c_str());
                else {
                    for (size_t i = 0; i < expected.size(); i++) {
                        if (expected[i] != actual[i]) {
                            yyerror(("Eroare: parametrul " + std::to_string(i + 1) + " are tip " + actual[i] +", dar se asteapta " + expected[i] + ".\n").c_str());
                            break;
                        }
                    }
                }
                $$ = new ExprAst{f->type, *$1 + "(...)", new ASTNode("OTHER")};
            }
            else {
                $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
            }
        }
        delete $1;
        delete $3;
    };

arg_list: /* gol */ {
            $$ = new std::vector<ExprAst>();
        }
        | arg_list_nonempty {
            $$ = $1;
        };

arg_list_nonempty: expr {
                    $$ = new std::vector<ExprAst>();
                    $$->push_back(*$1);
                    delete $1;
                }
                | arg_list_nonempty ',' expr {
                    $$ = $1;
                    $$->push_back(*$3);
                    delete $3;
                  };

primary: INT_LITERAL {
            $$ = new ExprAst{"int", std::to_string($1), new ASTNode("INT", std::to_string($1))};
        }
        | FLOAT_LITERAL {
            $$ = new ExprAst{"float", std::to_string($1), new ASTNode("FLOAT", std::to_string($1))};
        }
        | STRING_LITERAL {
            $$ = new ExprAst{"string", *$1, new ASTNode("STRING", *$1)};
            delete $1;
        }
        | CHAR_LITERAL {
            $$ = new ExprAst{"char", std::string(1,$1), new ASTNode("OTHER")};
        }
        | leftval {
            std::string t = typeOfLeftVal(currentScope, *$1);

            if ($1->find('.') != std::string::npos)
                $$ = new ExprAst{t, *$1, new ASTNode("OTHER")};
            else
                $$ = new ExprAst{t, *$1, new ASTNode("ID", *$1)};

            delete $1;
        }
        | call_expr { $$ = $1; } // va fi OTHER
        | new_expr  { $$ = $1; }
        | '(' expr ')' { $$ = $2; };
boolean_primary : BOOL_TRUE { $$ = new ExprAst{"bool", "true", new ASTNode("BOOL", "true")}; }

                  | BOOL_FALSE { $$ = new ExprAst{"bool", "false", new ASTNode("BOOL", "false")}; };

expr : boolean_expr;

arithmetic_expr : primary { $$ = $1; }
                 | '-' arithmetic_expr %prec UMINUS {
                    ASTNode* zero = nullptr;
                    if ($2->type == "float") zero = new ASTNode("FLOAT", "0.0");
                    else zero = new ASTNode("INT", "0");

                    ASTNode* op = new ASTNode("-");
                    op->left  = std::shared_ptr<ASTNode>(zero);
                    op->right = std::shared_ptr<ASTNode>($2->ast);

                    $$ = new ExprAst{$2->type, "-" + $2->value, op};
                    delete $2;
                 }
                 | arithmetic_expr '+' arithmetic_expr {
                         if ($1->type != $3->type) {
                            yyerror(("Eroare: tipuri incompatibile in expresie: " + $1->type + " + " + $3->type + ".\n").c_str());
                            $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                         }
                         else {
                            ASTNode* op = new ASTNode("+");
                            op->left  = std::shared_ptr<ASTNode>($1->ast);
                            op->right = std::shared_ptr<ASTNode>($3->ast);
                            $$ = new ExprAst{$1->type, $1->value + " + " + $3->value, op};
                         }
                        delete $1;
                        delete $3;
                    }
                 | arithmetic_expr '-' arithmetic_expr {
                        if ($1->type != $3->type) {
                            yyerror(("Eroare: tipuri incompatibile in expresie: " + $1->type + " - " + $3->type + ".\n").c_str());
                            $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                        }
                        else {
                            ASTNode* op = new ASTNode("-");
                            op->left  = std::shared_ptr<ASTNode>($1->ast);
                            op->right = std::shared_ptr<ASTNode>($3->ast);
                            $$ = new ExprAst{$1->type, $1->value + " - " + $3->value, op};
                        }                         
                        delete $1;
                        delete $3;
                    }
                 | arithmetic_expr '*' arithmetic_expr {
                        if ($1->type != $3->type) {
                            yyerror(("Eroare: tipuri incompatibile in expresie: " + $1->type + " * " + $3->type + ".\n").c_str());
                            $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                        }
                        else {
                            ASTNode* op = new ASTNode("*");
                            op->left  = std::shared_ptr<ASTNode>($1->ast);
                            op->right = std::shared_ptr<ASTNode>($3->ast);
                            $$ = new ExprAst{$1->type, $1->value + " * " + $3->value, op};
                        }                         
                        delete $1;
                        delete $3;
                    }
                 | arithmetic_expr '/' arithmetic_expr {
                        if ($1->type != $3->type) {
                            yyerror(("Eroare: tipuri incompatibile in expresie: " + $1->type + " / " + $3->type + ".\n").c_str());
                            $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                        }
                        else {
                            ASTNode* op = new ASTNode("/");
                            op->left  = std::shared_ptr<ASTNode>($1->ast);
                            op->right = std::shared_ptr<ASTNode>($3->ast);
                            $$ = new ExprAst{$1->type, $1->value + " / " + $3->value, op};
                        }                         
                        delete $1;
                        delete $3;
                    };

boolean_expr: arithmetic_expr { $$ = $1; }
               | boolean_primary { $$ = $1; }
               | boolean_expr OP_AND boolean_expr {
                    if ($1->type != "bool" || $3->type != "bool") {
                        yyerror("Eroare: operanzii pentru 'and' trebuie sa fie de tip bool.\n");
                        $$ = new ExprAst{"error","error", new ASTNode("OTHER")};
                    } else {
                        ASTNode* op = new ASTNode("&&");
                        op->left  = std::shared_ptr<ASTNode>($1->ast);
                        op->right = std::shared_ptr<ASTNode>($3->ast);
                        $$ = new ExprAst{"bool", $1->value + " and " + $3->value, op};
                    }
                    delete $1;
                    delete $3;
                }
               | boolean_expr OP_OR boolean_expr {
                    if ($1->type != "bool" || $3->type != "bool") {
                        yyerror("Eroare: operanzii pentru 'or' trebuie sa fie de tip bool.\n");
                        $$ = new ExprAst{"error","error", new ASTNode("OTHER")};
                    } else {
                        ASTNode* op = new ASTNode("||");
                        op->left  = std::shared_ptr<ASTNode>($1->ast);
                        op->right = std::shared_ptr<ASTNode>($3->ast);
                        $$ = new ExprAst{"bool", $1->value + " or " + $3->value, op};
                    }
                    delete $1;
                    delete $3;
                }
               | OP_NOT boolean_expr {
                    if ($2->type != "bool") {
                        yyerror("Eroare: operandul pentru 'not' trebuie sa fie de tip bool.\n");
                        $$ = new ExprAst{"error","error", new ASTNode("OTHER")};;
                    } else {
                        ASTNode* op = new ASTNode("!");
                        op->left = std::shared_ptr<ASTNode>($2->ast);
                        $$ = new ExprAst{"bool", "not " + $2->value, op};
                    }
                    delete $2;
                }
               | boolean_expr comp boolean_expr %prec OP_EQ {
                    if ($1->type != $3->type) {
                      yyerror(("Eroare: comparatie intre tipuri diferite: " + $1->type + " si " + $3->type + ".\n").c_str());
                      $$ = new ExprAst{"error","error", new ASTNode("OTHER")};
                    }
                    else {
                        ASTNode* op = new ASTNode(*$2); // "<", "==", etc.
                        op->left  = std::shared_ptr<ASTNode>($1->ast);
                        op->right = std::shared_ptr<ASTNode>($3->ast);
                        $$ = new ExprAst{"bool", $1->value + " " + *$2 + " " + $3->value, op};
                    }
                    delete $1;
                    delete $2;
                    delete $3;
               };


comp : '<' { $$ = new std::string("<"); }
     | '>' { $$ = new std::string(">"); }
     | OP_EQ { $$ = new std::string("=="); }
     | OP_NE { $$ = new std::string("!="); }
     | OP_LE { $$ = new std::string("<="); }
     | OP_GE { $$ = new std::string(">="); };

new_expr : NEW ID '(' arg_list ')' {
                Symbol* s = currentScope->findSymbol(*$2);
                if (!s || s->category != "class") {
                    yyerror(("Eroare: " + *$2 + " nu este o clasa declarata.\n").c_str());
                    $$ = new ExprAst{"error", "error", new ASTNode("OTHER")};
                }
                else $$ = new ExprAst{*$2, "new " + *$2, new ASTNode("OTHER")};
                delete $2;
                delete $4;
            };

%%

void yyerror(const char * s){
     std::cout << s << " at line: " << yylineno << std::endl;
     errorCount++;
}

int main(int argc, char** argv){
      yyin = fopen(argv[1], "r");
      if(!yyin) { printf("Eroare intrare!\n"); return 1; }

      yyparse();

     std::ofstream fout("tables.txt");
     for (auto table : allTables) {
         table->print(fout);
     }
     fout.close();

    if (errorCount == 0) 
        cout<< "The program is correct!" << endl;

     return (errorCount == 0) ? 0 : 1;
}