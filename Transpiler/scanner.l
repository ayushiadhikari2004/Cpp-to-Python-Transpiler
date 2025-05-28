%option yylineno
%{
/* prologue */

	#include <stdlib.h>
	#include "parser.tab.h"
	#include "ast.h" 
	#include <stdio.h>
	#include <string.h>
	#include "symtab.h"
	#include "translation.h"
	#include "utils.h"

	extern int yylineno;
	extern void debug_token(const char *token_name, const char *token_value);

#define YY_DECL int yylex(void)
%}

stdio           (std::)
delim		    [ \t]
ws 			    {delim}+
digit 		    [0-9]
int_number      [0]+|-?[1-9][0-9]*
float_number 	-?{digit}+(\.{digit}+)?(E[+-]?{digit}+)?
letter 		    [A-Za-z]
id 			    {letter}({letter}|{digit})*
bool_v		    true|false
string_v	    \"[^\"]*\"

%x 							comment
%x 							commentsl
%x 							library
%x 							namespacestd

%%

"/*" 						BEGIN(comment);
<comment>[^*\n]* 			/* eat anything that's not a '*' */
<comment>"*"+[^*/\n]* 		/* eat up '*'s not followed by '/'s */
<comment>\n 				/* possible new lines */
<comment>"*"+"/" 			BEGIN(INITIAL);
"//" 						BEGIN(commentsl);
<commentsl>[^\n]* 			/* eat anything that's not a new line */
<commentsl>\n 				BEGIN(INITIAL);
"#" 						BEGIN(library);
<library>[^\n]* 			/* eat anything that's not a new line */
<library>\n 				BEGIN(INITIAL);
"using namespace std;"		BEGIN(namespacestd);
<namespacestd>[^\n]* 		/* eat anything that's not a new line */
<namespacestd>\n 			BEGIN(INITIAL);


"if" 		{debug_token("IF", "if"); printf("KEYWORD 'IF' found at line %d.\n",yylineno);return(IF);}
"else" 		{debug_token("ELSE", "else"); printf("KEYWORD 'ELSE' found at line %d.\n",yylineno);return(ELSE);}
"float" 	{debug_token("FLOAT", "float"); printf("KEYWORD 'FLOAT' found at line %d.\n",yylineno);return(FLOAT) ;}
"int" 		{debug_token("INT", "int"); printf("KEYWORD 'INT' found at line %d.\n",yylineno);return(INT);}
"bool"		{debug_token("BOOL", "bool"); printf("KEYWORD 'BOOL' found at line %d.\n",yylineno);return(BOOL);}
"string"	{debug_token("STRING", "string"); printf("KEYWORD 'STRING' found at line %d.\n",yylineno);return(STRING);}
"return"	{debug_token("RETURN", "return"); printf("KEYWORD 'RETURN' found at line %d.\n",yylineno);return(RETURN);}
"cout"		{debug_token("COUT", "cout"); printf("KEYWORD 'COUT' found at line %d.\n",yylineno);return(COUT);}
"cin"		{debug_token("CIN", "cin"); printf("KEYWORD 'CIN' found at line %d.\n",yylineno);return(CIN);}
"for"		{debug_token("FOR", "for"); printf("KEYWORD 'FOR' found at line %d.\n",yylineno);return(FOR);}
"<<"		{debug_token("OUTPUT_OP", "<<"); printf("OPERATOR '<<' found at line %d.\n",yylineno);return(LSHIFT);}
">>"		{debug_token("INPUT_OP", ">>"); printf("OPERATOR '>>' found at line %d.\n",yylineno);return(RSHIFT);}
"<=" 		{debug_token("LE", "<="); printf("OPERATOR '<=' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(LE);}
"==" 		{debug_token("EQ", "=="); printf("OPERATOR '==' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(EEQ);}
">=" 		{debug_token("GE", ">="); printf("OPERATOR '>=' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(GE);}
"!=" 		{debug_token("NEQ", "!="); printf("OPERATOR '!=' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(NE);}
"<" 		{debug_token("LT", "<"); printf("OPERATOR '<' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(LT);}
"=" 		{debug_token("ASSIGN", "="); printf("OPERATOR '=' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(EQ);}
">" 		{debug_token("GT", ">"); printf("OPERATOR '>' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(GT);}
"&&" 		{debug_token("AND", "&&"); printf("OPERATOR 'AND' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(AND);}
"||" 		{debug_token("OR", "||"); printf("OPERATOR 'OR' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(OR);}
"(" 		{debug_token("LPAREN", "("); yylval.string=strdup(yytext);return(LPAR);}
")" 		{debug_token("RPAREN", ")"); yylval.string=strdup(yytext);return(RPAR);}
"{" 		{debug_token("LBRACE", "{"); yylval.string=strdup(yytext);return(LBRACE);}
"}" 		{debug_token("RBRACE", "}"); yylval.string=strdup(yytext);return(RBRACE);}
":" 		{debug_token("COLON", ":"); yylval.string=strdup(yytext);return(COLON);}
";" 		{debug_token("SEMICOLON", ";"); yylval.string=strdup(yytext);return(SEMICOLON);}
"," 		{debug_token("COMMA", ","); yylval.string=strdup(yytext);return(COMMA);}
"."			{debug_token("DOT", "."); yylval.string=strdup(yytext);return(DOT);}
"+" 		{debug_token("PLUS", "+"); printf("OPERATOR '+' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(ADD);}
"++" 		{debug_token("INCREMENT", "++"); printf("OPERATOR '++' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(INC);}
"-" 		{debug_token("MINUS", "-"); printf("OPERATOR '-' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(SUB);}
"--" 		{debug_token("DECREMENT", "--"); printf("OPERATOR '--' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(DEC);}
"*" 		{debug_token("MULT", "*"); printf("OPERATOR '*' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(MUL);}
"/" 		{debug_token("DIV", "/"); printf("OPERATOR '/' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(DIV);}
"class" 	{debug_token("CLASS", "class"); printf("KEYWORD 'CLASS' found at line %d.\n",yylineno);return(CLASS);}
"public"	{debug_token("PUBLIC", "public"); printf("KEYWORD 'PUBLIC' found at line %d.\n",yylineno);return(PUBLIC);}
"private"	{debug_token("PRIVATE", "private"); printf("KEYWORD 'PRIVATE' found at line %d.\n",yylineno);return(PRIVATE);}
"main"		{debug_token("MAIN", "main"); printf("KEYWORD 'MAIN' found at line %d.\n",yylineno);yylval.string=strdup(yytext);return(MAIN);}
"\n"        {/* no action and no return */}

{ws} 		    {/* no action and no return */}
{stdio}		    {/* no action and no return */}
{int_number} 	{yylval.string=strdup(yytext); printf("INT NUMBER '%s' found at line %d.\n",yylval.string,yylineno); 	return(INT_NUMBER) ;}
{float_number} 	{yylval.string=strdup(yytext); printf("FLOAT NUMBER '%s' found at line %d.\n",yylval.string,yylineno); return(FLOAT_NUMBER) ;}
{bool_v}	    {yylval.string=strdup(yytext); printf("BOOL VALUE '%s' found at line %d.\n",yylval.string,yylineno); 	return(BOOL_V) ;}
{id} 		    {yylval.string=strdup(yytext); printf("ID '%s' found at line %d.\n",yylval.string,yylineno); 			return(ID) ;}
{string_v}	    {yylval.string=strdup(yytext); printf("STRING '%s' found at line %d.\n",yylval.string,yylineno); 		return(STRING_V) ;}

.           {printf("Unknown character! \n"); return(UNKNOWN);}

%%

int yywrap(void) {
    return 1;
}
