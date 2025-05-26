#ifndef SYMTAB_H
#define SYMTAB_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "uthash.h"

// Symbol table structure
struct SymTab {
    char *name;
    int indent;
    struct SymTab *next;
    struct Symbol *symbols;
};

// Symbol structure
struct Symbol {
    char *name_sym;                /* name of symbol */
    SYMBOL_TYPE symbol_type;       /* type of symbol */
    DATA_TYPE data_type;          /* type of data */
    DATA_TYPE ret_type;           /* return type for functions */
    bool is_function;             /* is it a function? */
    char *param_func_name;        /* name of function if it's a parameter */
    bool is_class;                /* is it a class? */
    int line_num;                 /* line number where symbol is declared */
    union Value_sym value_sym;    /* value of symbol */
    struct AST_Node_FunctionDef *functionDef; /* function definition for function symbols */
    UT_hash_handle hh;            /* makes this structure hashable */
};

// Function declarations
struct SymTab *new_symtab(int indent, struct SymTab *next);
void delete_symtab(struct SymTab **ptable);
struct Symbol *add_symbol(char *name_sym, struct SymTab *table, SYMBOL_TYPE symbol_type, 
                         DATA_TYPE data_type, DATA_TYPE ret_type, bool is_function, 
                         char *param_func_name, bool is_class, int line_num, 
                         union Value_sym value_sym);
struct Symbol *find_symbol(char *name_sym, struct SymTab *table);
struct Symbol *find_symtab(char *name_sym, struct SymTab *table);
void delete_symbol(struct Symbol *symbol, struct SymTab *table);

#endif // SYMTAB_H
