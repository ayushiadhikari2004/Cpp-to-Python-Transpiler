#ifndef UTILS_H
#define UTILS_H

#include "ast.h"
#include "symtab.h"

// Function declarations
DATA_TYPE str_to_type(char *type_str);
bool search_class_body(char *var_name, struct AST_Node_Statements *root);
void check_function_call(struct AST_Node_FunctionCall *func_call);

#endif // UTILS_H 
