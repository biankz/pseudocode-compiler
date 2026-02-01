%{
#include "limbaj.tab.h" 
#include <cstdlib>
#include <cstdio>
#include <cstring>
%}
%x comment
%option noyywrap
%option yylineno
%%

"program" {return PROGRAM;}

"begin" {return T_BEGIN;}
"end" {return T_END;}

"int" {return TYPE_INT;}
"float" {return TYPE_FLOAT;}
"char" {return TYPE_CHAR;}
"string" {return TYPE_STRING;}
"bool" {return TYPE_BOOL;}
"void" {return TYPE_VOID;}

"true" {return BOOL_TRUE;}
"false" {return BOOL_FALSE;}

"class" {return CLASS;}
"new" {return NEW;}
"public"    { return PUBLIC; }
"private"   { return PRIVATE; }
"protected" { return PROTECTED; }
"let" {return LET;}

"Print" {return PRINT;}

"if" {return IF;}
"then" {return THEN;}
"else" {return ELSE;}

"while" {return WHILE;}
"do" {return DO;}
"for" {return FOR;}

"fn" {return FN;}
"return" {return RETURN;}

"and" {return OP_AND;}
"or" {return OP_OR;}
"not" {return OP_NOT;}

"==" {return OP_EQ;}
"<>" {return OP_NE;}  
"<=" {return OP_LE;}
">=" {return OP_GE;}
"<" {return '<';}
">" {return '>';}

"+" {return '+';}
"-" {return '-';}
"*" {return '*';}
"/" {return '/';}
"%" {return '%';}

"<-" {return ASSIGN;} 
"->" {return ARROW;}

"." {return DOT;}
"," {return ',';} 
":" { return ':'; }

"(" {return '(';}
")" {return ')';}

[0-9]+\.[0-9]+([eE][+-]?[0-9]+)? {
    yylval.Float=atof(yytext);
    return FLOAT_LITERAL;
}

0|[1-9][0-9]* {
    yylval.Int=atoi(yytext);
    return INT_LITERAL;
}

\'(\\.|[^\\\'])\' {
    yylval.Char = yytext[1]; 
    return CHAR_LITERAL;
}

\"(\\.|[^"\\])*\" {
    yylval.Str = new std::string(yytext);
    return STRING_LITERAL;
}

[a-zA-Z_][a-zA-Z0-9_]* { 
    yylval.Str = new std::string(yytext); 
    return ID;
}

[ \t]+ ; /* ignora spatiul alb */
(\r\n|\r|\n)+ ; /* ignor newlines */
";" { return ';'; }

"/*" {BEGIN comment;}
<comment>"*/" {BEGIN INITIAL;}
<comment>.|\n {/* ignora continutul */}
<comment><<EOF>> {
    fprintf(stderr, "Eroare Lexicala: Comentariu bloc neinchis!\n");
    return 0;
}

<<EOF>> {return 0;}
. {fprintf(stderr, "Eroare Lexicala: Caracter neasteptat: %s\n", yytext);}
%%
