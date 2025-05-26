#include "symtab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Create new symbol table
struct SymTab *new_symtab(int indent, struct SymTab *next) {
    struct SymTab *table = (struct SymTab *)malloc(sizeof(struct SymTab));
    if (!table) {
        fprintf(stderr, "Error: Failed to allocate memory for symbol table\n");
        return NULL;
    }
    
    table->name = NULL;
    table->indent = indent;
    table->next = next;
    table->symbols = NULL;
    return table;
}

// Delete symbol table
void delete_symtab(struct SymTab **ptable) {
    if (!ptable || !*ptable) return;
    struct SymTab *table = *ptable;
    printf("[DEBUG] Deleting symbol table: %p\n", table);
    struct Symbol *current, *tmp;
    HASH_ITER(hh, table->symbols, current, tmp) {
        printf("[DEBUG] Deleting symbol: %s (%p)\n", current->name_sym, current);
        HASH_DEL(table->symbols, current);
        free(current->name_sym);
        free(current->param_func_name);
        free(current);
    }
    free(table->name);
    free(table);
    *ptable = NULL;
    printf("[DEBUG] Symbol table deleted.\n");
}

// Add symbol to table
struct Symbol *add_symbol(char *name_sym, struct SymTab *table, SYMBOL_TYPE symbol_type,
                         DATA_TYPE data_type, DATA_TYPE ret_type, bool is_function,
                         char *param_func_name, bool is_class, int line_num,
                         union Value_sym value_sym) {
    if (!table || !name_sym) return NULL;
    
    struct Symbol *symbol;
    HASH_FIND_STR(table->symbols, name_sym, symbol);
    
    if (symbol) {
        fprintf(stderr, "Error: Symbol '%s' already exists in scope\n", name_sym);
        return NULL;
    }
    
    symbol = (struct Symbol *)malloc(sizeof(struct Symbol));
    if (!symbol) {
        fprintf(stderr, "Error: Failed to allocate memory for symbol\n");
        return NULL;
    }
    
    symbol->name_sym = strdup(name_sym);
    symbol->symbol_type = symbol_type;
    symbol->data_type = data_type;
    symbol->ret_type = ret_type;
    symbol->is_function = is_function;
    symbol->param_func_name = param_func_name ? strdup(param_func_name) : NULL;
    symbol->is_class = is_class;
    symbol->line_num = line_num;
    symbol->value_sym = value_sym;
    
    HASH_ADD_STR(table->symbols, name_sym, symbol);
    return symbol;
}

// Find symbol in current table
struct Symbol *find_symbol(char *name_sym, struct SymTab *table) {
    if (!table || !name_sym) return NULL;
    
    struct Symbol *symbol;
    HASH_FIND_STR(table->symbols, name_sym, symbol);
    return symbol;
}

// Find symbol in all tables
struct Symbol *find_symtab(char *name_sym, struct SymTab *table) {
    if (!name_sym) return NULL;
    
    struct Symbol *symbol;
    while (table) {
        symbol = find_symbol(name_sym, table);
        if (symbol) return symbol;
        table = table->next;
    }
    return NULL;
}

// Delete symbol from table
void delete_symbol(struct Symbol *symbol, struct SymTab *table) {
    if (!symbol || !table) return;
    printf("[DEBUG] Deleting single symbol: %s (%p) from table %p\n", symbol->name_sym, symbol, table);
    HASH_DEL(table->symbols, symbol);
    free(symbol->name_sym);
    free(symbol->param_func_name);
    free(symbol);
} 