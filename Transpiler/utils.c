#include "utils.h"
#include <string.h>
#include <stdio.h>

// External declarations
extern struct SymTab *local_table;
extern int yylineno;
extern int n_error;

// Convert string type to DATA_TYPE enum
DATA_TYPE str_to_type(char *type_str) {
    if (strcmp(type_str, "int") == 0) {
        return DATA_TYPE_INT;
    } else if (strcmp(type_str, "float") == 0) {
        return DATA_TYPE_FLOAT;
    } else if (strcmp(type_str, "string") == 0) {
        return DATA_TYPE_STRING;
    } else if (strcmp(type_str, "bool") == 0) {
        return DATA_TYPE_BOOL;
    }
    return DATA_TYPE_NONE;
}

// Search for a variable or function in class body
bool search_class_body(char *var_name, struct AST_Node_Statements *root) {
    if (root == NULL) {
        return false;
    }

    // Use a stack to track nodes to visit
    struct AST_Node_Statements *stack[1000] = {NULL};
    int stack_top = 0;
    stack[stack_top++] = root;

    while (stack_top > 0) {
        struct AST_Node_Statements *current = stack[--stack_top];
        
        // Check current node
        if (current->left != NULL) {
            struct AST_Node_Instruction *instr = current->left;
            
            // Check for variable declaration/assignment
            if (instr->n_type == INIT_NODE || instr->n_type == ASSIGN_NODE) {
                if (strcmp(instr->value.init->assign->var, var_name) == 0) {
                    return true;
                }
            }
            // Check for function definition
            else if (instr->n_type == FUNC_DEF_NODE) {
                if (strcmp(instr->value.functionDef->func_name, var_name) == 0) {
                    return true;
                }
            }
        }

        // Add right child to stack if it exists
        if (current->right != NULL) {
            if (stack_top < 1000) {
                stack[stack_top++] = current->right;
            } else {
                fprintf(stderr, "Error: Stack overflow in search_class_body\n");
                return false;
            }
        }
    }

    return false;
}

// Check if function call is valid
void check_function_call(struct AST_Node_FunctionCall *func_call) {
    if (func_call == NULL) {
        return;
    }

    // Find function in symbol table
    struct Symbol *func_sym = find_symtab(func_call->func_name, local_table);
    if (func_sym == NULL || !func_sym->is_function) {
        printf("\n\n\t***Error: Function %s not found***\n\t***Line: %d***\n\n\n", 
               func_call->func_name, yylineno);
        n_error++;
        return;
    }

    // Check parameter count and types
    struct AST_Node_Params *call_params = func_call->params;
    struct AST_Node_Params *def_params = func_sym->functionDef->params;
    
    while (call_params != NULL && def_params != NULL) {
        if (call_params->call_param->val_type != def_params->decl_param->data_type) {
            printf("\n\n\t***Error: Parameter type mismatch in function %s***\n\t***Line: %d***\n\n\n",
                   func_call->func_name, yylineno);
            n_error++;
            return;
        }
        call_params = call_params->next_param;
        def_params = def_params->next_param;
    }

    // Check if parameter counts match
    if (call_params != NULL || def_params != NULL) {
        printf("\n\n\t***Error: Parameter count mismatch in function %s***\n\t***Line: %d***\n\n\n",
               func_call->func_name, yylineno);
        n_error++;
    }
} 