#include "translation.h"
#include "ast.h"
#include "symtab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int indent_counter = 0;
static int traverse_depth = 0;  // Track recursion depth
#define MAX_TRAVERSE_DEPTH 1000  // Safety limit
static bool g_return_has_been_emitted_for_current_func = false; // Flag for duplicate return

// Translate AST node to Python code
char *translate_ast_node(struct AST_Node *node) {
    if (!node) return strdup("");
    
    printf("[DEBUG] translate_ast_node: type=%d\n", node->n_type);
    
    char *result = NULL;
    switch (node->n_type) {
        case BIN_OP_NODE: {
            struct AST_Node_BinOp *binop = (struct AST_Node_BinOp *)node->value;
            char *left = translate_ast_node(binop->left);
            char *right = translate_ast_node(binop->right);
            
            // Handle special cases for operators
            if (strcmp(binop->op, "&&") == 0) {
                asprintf(&result, "(%s and %s)", left, right);
            } else if (strcmp(binop->op, "||") == 0) {
                asprintf(&result, "(%s or %s)", left, right);
            } else {
                asprintf(&result, "(%s %s %s)", left, binop->op, right);
            }
            
            free(left);
            free(right);
            break;
        }
        
        case UN_OP_NODE: {
            struct AST_Node_UnOp *unop = (struct AST_Node_UnOp *)node->value;
            char *operand = translate_ast_node(unop->operand);
            
            // Handle special cases for operators
            if (strcmp(unop->op, "!") == 0) {
                asprintf(&result, "(not %s)", operand);
            } else {
                asprintf(&result, "(%s%s)", unop->op, operand);
            }
            
            free(operand);
            break;
        }
        
        case NUM_NODE: {
            struct AST_Node_Num *num = (struct AST_Node_Num *)node->value;
            asprintf(&result, "%d", num->value);
            break;
        }
        
        case FLOAT_NODE: {
            struct AST_Node_Float *float_val = (struct AST_Node_Float *)node->value;
            asprintf(&result, "%f", float_val->value);
            break;
        }
        
        case STRING_NODE: {
            struct AST_Node_String *str = (struct AST_Node_String *)node->value;
            asprintf(&result, "\"%s\"", str->value);
            break;
        }
        
        case BOOL_NODE: {
            struct AST_Node_Bool *bool_val = (struct AST_Node_Bool *)node->value;
            asprintf(&result, "%s", bool_val->value ? "True" : "False");
            break;
        }
        
        case VAR_NODE: {
            struct AST_Node_Var *var = (struct AST_Node_Var *)node->value;
            result = strdup(var->name);
            break;
        }
        
        case FUNC_CALL_NODE: {
            struct AST_Node_FunctionCall *func_call = (struct AST_Node_FunctionCall *)node->value;
            char *params = translate_params(func_call->params);
            asprintf(&result, "%s(%s)", func_call->func_name, params);
            free(params);
            break;
        }
        
        case OBJ_CALL_NODE: {
            struct AST_Node_ObjectCall *obj_call = (struct AST_Node_ObjectCall *)node->value;
            char *params = translate_params(obj_call->params);
            asprintf(&result, "%s.%s(%s)", obj_call->obj_name, obj_call->func_name, params);
            free(params);
            break;
        }
        
        default:
            result = strdup("");
            break;
    }
    
    return result ? result : strdup("");
}

// Translate parameters to Python code
char *translate_params(struct AST_Node_Params *params) {
    if (!params) return strdup("");
    
    char *result = NULL;
    char *param_str = NULL;
    
    if (params->decl_param) {
        // Declaration parameter (for function definition)
        // In Python we don't need to specify types, so just use the variable name
        param_str = strdup(params->decl_param->assign->var);
    } else if (params->call_param) {
        // Call parameter (for function call)
        struct AST_Node_Operand *operand = malloc(sizeof(struct AST_Node_Operand));
        operand->operand_type = params->call_param->operand_type;
        memcpy(&operand->value, &params->call_param->value, sizeof(union Value_sym));
        param_str = translate_operand(operand);
        free(operand);
        
        if (!param_str || strlen(param_str) == 0) {
            // Handle empty or null parameters
            free(param_str);
            param_str = strdup("");
        }
    } else {
        param_str = strdup("");
    }
    
    if (params->next_param) {
        // Handle next parameter
        char *next_str = translate_params(params->next_param);
        
        // Only add comma if both parameters are non-empty
        if (strlen(param_str) > 0 && strlen(next_str) > 0) {
            asprintf(&result, "%s, %s", param_str, next_str);
        } else if (strlen(param_str) > 0) {
            result = strdup(param_str);
        } else {
            result = strdup(next_str);
        }
        
        free(next_str);
    } else {
        result = strdup(param_str);
    }
    
    free(param_str);
    return result;
}

// Translate operand to Python code
char *translate_operand(struct AST_Node_Operand *operand) {
    if (!operand) return strdup("");
    
    char *result = NULL;
    
    switch (operand->operand_type) {
        case CONTENT_TYPE_ID:
            return strdup(operand->value.val ? operand->value.val : "");
        case CONTENT_TYPE_INT_NUMBER:
        case CONTENT_TYPE_FLOAT_NUMBER:
        case CONTENT_TYPE_STRING:
        case CONTENT_TYPE_BOOL:
            return strdup(operand->value.val ? operand->value.val : "");
        case CONTENT_TYPE_EXPRESSION: {
            // Handle expressions (like a + b)
            struct AST_Node_Expression *expr = operand->value.expr;
            if (!expr) return strdup("");
            
            // Safety check for null operators
            if (!expr->left_op || !expr->right_op) {
                return strdup("None # Invalid expression");
            }
            
            // Convert C operators to Python operators
            char *op = strdup(expr->op);
            if (strcmp(op, "&&") == 0) {
                free(op);
                op = strdup("and");
            } else if (strcmp(op, "||") == 0) {
                free(op);
                op = strdup("or");
            } else if (strcmp(op, "+=") == 0 && strcmp(expr->right_op->value.val, "1") == 0) {
                // Handle increment
                char *var = translate_operand(expr->left_op);
                asprintf(&result, "%s + 1", var);
                free(var);
                free(op);
                return result;
            } else if (strcmp(op, "-=") == 0 && strcmp(expr->right_op->value.val, "1") == 0) {
                // Handle decrement
                char *var = translate_operand(expr->left_op);
                asprintf(&result, "%s - 1", var);
                free(var);
                free(op);
                return result;
            }
            
            // Handle nested expressions (like (a + b) * c)
            char *left;
            if (expr->left_op->operand_type == CONTENT_TYPE_EXPRESSION) {
                left = translate_operand(expr->left_op);
                // If left operand is an expression, wrap it in parentheses
                char *temp = left;
                asprintf(&left, "(%s)", temp);
                free(temp);
            } else {
                left = translate_operand(expr->left_op);
            }
            
            char *right;
            if (expr->right_op->operand_type == CONTENT_TYPE_EXPRESSION) {
                right = translate_operand(expr->right_op);
                // If right operand is an expression, wrap it in parentheses
                char *temp = right;
                asprintf(&right, "(%s)", temp);
                free(temp);
            } else {
                right = translate_operand(expr->right_op);
            }
            
            if (left && right && op) {
                asprintf(&result, "%s %s %s", left, op, right);
            } else {
                result = strdup("None # Error in expression");
            }
            
            free(left);
            free(right);
            free(op);
            return result;
        }
        case CONTENT_TYPE_FUNCTION:
            if (operand->value.funca) {
                return translate_ast_node((struct AST_Node *)operand->value.funca);
            }
            return strdup("");
        default:
            return strdup("");
    }
}

// Translate statements to Python code
char *translate_statements(struct AST_Node_Statements *statements, int indent_level) {
    if (!statements) return strdup("");
    
    char *result = NULL;
    char *left = translate_instruction(statements->left, indent_level);
    
    if (statements->right) {
        char *right = translate_statements(statements->right, indent_level);
        asprintf(&result, "%s\n%s", left, right);
        free(right);
    } else {
        result = strdup(left);
    }
    
    free(left);
    return result;
}

// Translate instruction to Python code
char *translate_instruction(struct AST_Node_Instruction *instr, int indent_level) {
    if (!instr) return strdup("");
    
    char *indent = (char *)malloc(indent_level * 4 + 1);
    memset(indent, ' ', indent_level * 4);
    indent[indent_level * 4] = '\0';
    
    char *result = NULL;
    switch (instr->n_type) {
        case INIT_NODE: {
            struct AST_Node_Init *init = (struct AST_Node_Init *)instr->value.init;
            struct AST_Node_Operand *operand = malloc(sizeof(struct AST_Node_Operand));
            operand->operand_type = init->assign->a_type;
            memcpy(&operand->value, &init->assign->a_val, sizeof(union Value_sym));
            char *value = translate_operand(operand);
            free(operand);
            asprintf(&result, "%s%s = %s", indent, init->assign->var, value);
            free(value);
            break;
        }
        
        case ASSIGN_NODE: {
            struct AST_Node_Assign *assign = (struct AST_Node_Assign *)instr->value.assign;
            struct AST_Node_Operand *operand = malloc(sizeof(struct AST_Node_Operand));
            operand->operand_type = assign->a_type;
            memcpy(&operand->value, &assign->a_val, sizeof(union Value_sym));
            char *value = translate_operand(operand);
            free(operand);
            asprintf(&result, "%s%s = %s", indent, assign->var, value);
            free(value);
            break;
        }
        
        case FUNC_DEF_NODE: {
            struct AST_Node_FunctionDef *func_def = (struct AST_Node_FunctionDef *)instr->value.functionDef;
            char *params = translate_params(func_def->params);
            char *body = translate_statements(func_def->f_body->func_body, indent_level + 1);
            asprintf(&result, "%sdef %s(%s):\n%s", indent, func_def->func_name, params, body);
            free(params);
            free(body);
            break;
        }
        
        case CLASS_DEF_NODE: {
            struct AST_Node_ClassDef *class_def = (struct AST_Node_ClassDef *)instr->value.classNode;
            char *body = translate_statements(class_def->body, indent_level + 1);
            asprintf(&result, "%sclass %s:\n%s", indent, class_def->class_name, body);
            free(body);
            break;
        }
        
        case IF_NODE: {
            struct AST_Node_If *if_node = (struct AST_Node_If *)instr->value.ifNode;
            struct AST_Node_Operand *operand = malloc(sizeof(struct AST_Node_Operand));
            operand->operand_type = if_node->condition->left_op->operand_type;
            memcpy(&operand->value, &if_node->condition->left_op->value, sizeof(union Value_sym));
            char *condition = translate_operand(operand);
            free(operand);
            char *body = translate_statements(if_node->if_body, indent_level + 1);
            
            // Handle else-if part
            char *elif_part = "";
            if (if_node->else_if) {
                struct AST_Node_Operand *elif_operand = malloc(sizeof(struct AST_Node_Operand));
                elif_operand->operand_type = if_node->else_if->condition->left_op->operand_type;
                memcpy(&elif_operand->value, &if_node->else_if->condition->left_op->value, sizeof(union Value_sym));
                char *elif_condition = translate_operand(elif_operand);
                free(elif_operand);
                char *elif_body = translate_statements(if_node->else_if->elif_body, indent_level + 1);
                asprintf(&elif_part, "%selif %s:\n%s", indent, elif_condition, elif_body);
                free(elif_condition);
                free(elif_body);
            }
            
            // Handle else part
            char *else_part = "";
            if (if_node->else_body) {
                char *else_body = translate_statements(if_node->else_body->else_body, indent_level + 1);
                asprintf(&else_part, "%selse:\n%s", indent, else_body);
                free(else_body);
            }
            
            // Combine all parts
            asprintf(&result, "%sif %s:\n%s%s%s", indent, condition, body, elif_part, else_part);
            
            free(condition);
            free(body);
            if (strlen(elif_part) > 0) free(elif_part);
            if (strlen(else_part) > 0) free(else_part);
            break;
        }
        
        case WHILE_NODE: {
            struct AST_Node_While *while_node = (struct AST_Node_While *)instr->value.statements;
            struct AST_Node_Expression *expr = (struct AST_Node_Expression *)while_node->condition;
            char *condition = translate_operand(expr->left_op);
            char *body = translate_statements(while_node->body, indent_level + 1);
            asprintf(&result, "%swhile %s:\n%s", indent, condition, body);
            free(condition);
            free(body);
            break;
        }
        
        case FOR_NODE: {
            struct AST_Node_For *for_node = (struct AST_Node_For *)instr->value.forNode;
            if (!for_node) break;

            char *init_val_str = NULL;
            if (for_node->init) {
                struct AST_Node_Operand temp_init_op;
                temp_init_op.operand_type = for_node->init->a_type;
                temp_init_op.value = for_node->init->a_val;
                init_val_str = translate_operand(&temp_init_op);
            }

            char *cond_upper_bound_str = NULL;
            if (for_node->condition && for_node->condition->right_op) {
                cond_upper_bound_str = translate_operand(for_node->condition->right_op);
            }

            if (for_node->init && init_val_str && cond_upper_bound_str) {
                long upper_bound_val = strtol(cond_upper_bound_str, NULL, 10);
                char range_stop_val_str[32];
                if (for_node->condition && strcmp(for_node->condition->op, "<=") == 0) {
                    sprintf(range_stop_val_str, "%ld", upper_bound_val + 1);
                } else {
                    sprintf(range_stop_val_str, "%ld", upper_bound_val);
                }
                print_indent(indent_level);
                fprintf(fptr, "for %s in range(%s, %s):\n",
                        for_node->init->var,
                        init_val_str,
                        range_stop_val_str);
            } else {
                print_indent(indent_level);
                fprintf(fptr, "# Error translating for loop range (components missing)\n");
            }

            if (init_val_str) free(init_val_str);
            if (cond_upper_bound_str) free(cond_upper_bound_str);

            indent_counter++;
            traverse(for_node->for_body);
            indent_counter--;
            break;
        }
        
        case PRINT_NODE: {
            struct AST_Node_Print *print_node = (struct AST_Node_Print *)instr->value.outputNode;
            char *value = translate_ast_node((struct AST_Node *)print_node->value);
            asprintf(&result, "%sprint(%s)", indent, value);
            free(value);
            break;
        }
        
        case RETURN_NODE: {
            struct AST_Node_Return *return_node = (struct AST_Node_Return *)instr->value.returnNode;
            translate_return(return_node);
            break;
        }
        
        case BREAK_NODE:
            asprintf(&result, "%sbreak", indent);
            break;
            
        case CONTINUE_NODE:
            asprintf(&result, "%scontinue", indent);
            break;
            
        default:
            result = strdup("");
            break;
    }
    
    free(indent);
    return result ? result : strdup("");
}

void traverse(struct AST_Node_Statements *root) {
    if (root == NULL) return;
    
    // Prevent infinite recursion
    if (traverse_depth++ > MAX_TRAVERSE_DEPTH) {
        fprintf(stderr, "Error: Maximum recursion depth exceeded at node %p\n", (void*)root);
        traverse_depth--;
        return;
    }
    
    printf("[DEBUG] traverse: depth=%d, left=%p, right=%p\n", 
           traverse_depth, (void*)root->left, (void*)root->right);
    
    // Check for circular references
    static struct AST_Node_Statements *visited_nodes[1000] = {NULL};
    static int visited_count = 0;
    
    // Check if this node has been visited before
    for (int i = 0; i < visited_count; i++) {
        if (visited_nodes[i] == root) {
            fprintf(stderr, "Error: Circular reference detected at node %p\n", (void*)root);
            traverse_depth--;
            return;
        }
    }
    
    // Add current node to visited list
    if (visited_count < 1000) {
        visited_nodes[visited_count++] = root;
    }
    
    if (root->left == NULL && root->right == NULL) {
        traverse_depth--;
        return;
    }
    
    if (root->left != NULL) {
        struct AST_Node_Instruction *left = root->left;
        printf("[DEBUG] Processing node type: %d\n", left->n_type);
        
        switch (left->n_type) {
            case INIT_NODE:
                translate_init(left->value.init);
                break;
            case ASSIGN_NODE:
                translate_assign(left->value.assign);
                break;
            case FUNC_CALL_NODE:
                print_indent(indent_counter);
                translate_func_call(left->value.functionCall);
                break;
            case FUNC_DEF_NODE:
                translate_func_def(left->value.functionDef);
                break;
            case IF_NODE:
                translate_if(left->value.ifNode);
                break;
            case ELSE_NODE:
                translate_else(left->value.elseNode);
                break;
            case ELSE_IF_NODE:
                translate_else_if(left->value.elseIfNode);
                break;
            case FOR_NODE: {
                struct AST_Node_For *for_node = left->value.forNode;
                if (!for_node) break;

                char *init_val_str = NULL;
                if (for_node->init) {
                    struct AST_Node_Operand temp_init_op;
                    temp_init_op.operand_type = for_node->init->a_type;
                    temp_init_op.value = for_node->init->a_val;
                    init_val_str = translate_operand(&temp_init_op);
                }

                char *cond_upper_bound_str = NULL;
                if (for_node->condition && for_node->condition->right_op) {
                    cond_upper_bound_str = translate_operand(for_node->condition->right_op);
                }

                if (for_node->init && init_val_str && cond_upper_bound_str) {
                    long upper_bound_val = strtol(cond_upper_bound_str, NULL, 10);
                    char range_stop_val_str[32];
                    if (for_node->condition && strcmp(for_node->condition->op, "<=") == 0) {
                        sprintf(range_stop_val_str, "%ld", upper_bound_val + 1);
                    } else {
                        sprintf(range_stop_val_str, "%ld", upper_bound_val);
                    }
                    print_indent(indent_counter);
                    fprintf(fptr, "for %s in range(%s, %s):\n",
                            for_node->init->var,
                            init_val_str,
                            range_stop_val_str);
                } else {
                    print_indent(indent_counter);
                    fprintf(fptr, "# Error translating for loop range (components missing)\n");
                }

                if (init_val_str) free(init_val_str);
                if (cond_upper_bound_str) free(cond_upper_bound_str);

                indent_counter++;
                traverse(for_node->for_body);
                indent_counter--;
                break;
            }
            case INPUT_NODE:
                translate_input(left->value.inputNode);
                break;
            case OUTPUT_NODE:
                translate_output(left->value.outputNode);
                break;
            case CLASS_NODE:
                translate_class(left->value.classNode);
                break;
            case CLASS_CHILD_NODE:
                translate_class_child(left->value.classNode);
                break;
            case OBJECT_NODE:
                translate_object(left->value.objectNode);
                break;
            case ACCESS_CLASS_NODE:
                translate_access_class(left->value.objectNode);
                break;
            case RETURN_NODE:
                translate_return(left->value.returnNode);
                break;
            default:
                printf("[ERROR] Unknown node type: %d\n", left->n_type);
                break;
        }
    }
    
    if (root->right != NULL) {
        traverse(root->right);
    }
    
    traverse_depth--;
}

// Helper function to get Python type from DATA_TYPE
char* python_type(DATA_TYPE type) {
    switch (type) {
        case DATA_TYPE_INT:
            return "int";
        case DATA_TYPE_FLOAT:
            return "float";
        case DATA_TYPE_STRING:
            return "str";
        case DATA_TYPE_BOOL:
            return "bool";
        case DATA_TYPE_NONE:
            return "None";
        default:
            return "None";
    }
}

// Helper function to get string representation of node type
char* node_type(NODE_TYPE type) {
    switch (type) {
        case INIT_NODE:
            return "INIT_NODE";
        case ASSIGN_NODE:
            return "ASSIGN_NODE";
        case FUNC_CALL_NODE:
            return "FUNC_CALL_NODE";
        case FUNC_DEF_NODE:
            return "FUNC_DEF_NODE";
        case IF_NODE:
            return "IF_NODE";
        case ELSE_NODE:
            return "ELSE_NODE";
        case ELSE_IF_NODE:
            return "ELSE_IF_NODE";
        case FOR_NODE:
            return "FOR_NODE";
        case INPUT_NODE:
            return "INPUT_NODE";
        case OUTPUT_NODE:
            return "OUTPUT_NODE";
        case CLASS_NODE:
            return "CLASS_NODE";
        case CLASS_CHILD_NODE:
            return "CLASS_CHILD_NODE";
        case OBJECT_NODE:
            return "OBJECT_NODE";
        case ACCESS_CLASS_NODE:
            return "ACCESS_CLASS_NODE";
        case RETURN_NODE:
            return "RETURN_NODE";
        default:
            return "UNKNOWN_NODE";
    }
}

void translate_init(struct AST_Node_Init *init) {
    if (!init) return;
    
    print_indent(indent_counter);
    
    // For simple variable declaration with no initial value,
    // initialize with default value based on data type
    if (init->assign->a_val.val == NULL) {
        switch (init->data_type) {
            case DATA_TYPE_INT:
                fprintf(fptr, "%s = 0\n", init->assign->var);
                break;
            case DATA_TYPE_FLOAT:
                fprintf(fptr, "%s = 0.0\n", init->assign->var);
                break;
            case DATA_TYPE_STRING:
                fprintf(fptr, "%s = \"\"\n", init->assign->var);
                break;
            case DATA_TYPE_BOOL:
                fprintf(fptr, "%s = False\n", init->assign->var);
                break;
            default:
                fprintf(fptr, "%s = None\n", init->assign->var);
                break;
        }
        return;
    }
    
    // Handle variable initialization with a value
    struct AST_Node_Operand *operand = malloc(sizeof(struct AST_Node_Operand));
    if (!operand) {
        fprintf(fptr, "%s = None  # Error in translation\n", init->assign->var);
        return;
    }
    
    operand->operand_type = init->assign->a_type;
    memcpy(&operand->value, &init->assign->a_val, sizeof(union Value_sym));
    char *value = translate_operand(operand);
    fprintf(fptr, "%s = %s\n", init->assign->var, value ? value : "None");
    
    free(operand);
    if (value) free(value);
}

void translate_func_call(struct AST_Node_FunctionCall *func_call) {
    if (!func_call) return;
    char *params = translate_params(func_call->params);
    fprintf(fptr, "%s(%s)\n", func_call->func_name, params);
    free(params);
}

void translate_func_def(struct AST_Node_FunctionDef *func_def) {
    if (!func_def) return;
    g_return_has_been_emitted_for_current_func = false; // Reset flag for new function
    printf("[DEBUG] Translating function: %s\n", func_def->func_name);
    
    char *params = translate_params(func_def->params);
    
    if (strcmp(func_def->func_name, "main") == 0) {
        fprintf(fptr, "def main():\n");
    } 
    else if (func_def->is_class_method) {
        if (params && strlen(params) > 0) {
            fprintf(fptr, "def %s(self, %s):\n", func_def->func_name, params);
        } else {
            fprintf(fptr, "def %s(self):\n", func_def->func_name);
        }
    }
    else {
        fprintf(fptr, "def %s(%s):\n", func_def->func_name, params);
    }
    
    free(params);
    indent_counter++;
    
    if (func_def->f_body && func_def->f_body->func_body) {
        traverse(func_def->f_body->func_body);
    }
    
    // Check if a return was already handled by translate_return via traverse
    if (!g_return_has_been_emitted_for_current_func) {
        if (func_def->f_body && func_def->f_body->return_op) {
            // This case might be redundant if traverse->translate_return sets the flag
            // but kept for safety if return_op exists but wasn't traversed (e.g. dead code)
            print_indent(indent_counter);
            char *return_val = translate_operand(func_def->f_body->return_op);
            fprintf(fptr, "return %s\n", return_val ? return_val : "None");
            if (return_val) free(return_val);
            g_return_has_been_emitted_for_current_func = true; // Mark return emitted
        } else if (strcmp(func_def->func_name, "main") == 0 && func_def->return_type == DATA_TYPE_INT) {
             // Special handling for implicit return 0 in C++ main if not handled by traverse
            print_indent(indent_counter);
            fprintf(fptr, "return 0\n"); 
            g_return_has_been_emitted_for_current_func = true;
        } else {
            // Default return for functions not returning anything explicitly if not void
            // For void C++ functions (or those where Python equivalent is None)
            print_indent(indent_counter);
            fprintf(fptr, "return None\n");
            g_return_has_been_emitted_for_current_func = true; // Python functions return None by default if no return statement
        }
    }
    
    indent_counter--;
    
    if (strcmp(func_def->func_name, "main") == 0) {
        fprintf(fptr, "\nif __name__ == \"__main__\":\n");
        print_indent(1);
        fprintf(fptr, "    main()\n");
    }
}

void translate_expr(struct AST_Node_Expression *expr) {
    if (!expr) return;
    char *left = translate_operand(expr->left_op);
    char *right = translate_operand(expr->right_op);
    fprintf(fptr, "%s %s %s", left, expr->op, right);
    free(left);
    free(right);
}

void translate_if(struct AST_Node_If *if_statement) {
    if (!if_statement) return;
    print_indent(indent_counter);
    fprintf(fptr, "if ");
    translate_expr(if_statement->condition);
    fprintf(fptr, ":\n");
    indent_counter++;
    traverse(if_statement->if_body);
    indent_counter--;

    // Handle else-if part
    if (if_statement->else_if) {
        print_indent(indent_counter);
        fprintf(fptr, "elif ");
        translate_expr(if_statement->else_if->condition);
        fprintf(fptr, ":\n");
        indent_counter++;
        traverse(if_statement->else_if->elif_body);
        indent_counter--;
    }

    // Handle else part
    if (if_statement->else_body) {
        print_indent(indent_counter);
        fprintf(fptr, "else:\n");
        indent_counter++;
        traverse(if_statement->else_body->else_body);
        indent_counter--;
    }
}

void translate_else_if(struct AST_Node_Else_If *else_if_statement) {
    if (!else_if_statement) return;
    fprintf(fptr, "elif ");
    translate_expr(else_if_statement->condition);
    fprintf(fptr, ":\n");
    indent_counter++;
    traverse(else_if_statement->elif_body);
    indent_counter--;
}

void translate_else(struct AST_Node_Else *else_statement) {
    if (!else_statement) return;
    fprintf(fptr, "else:\n");
    indent_counter++;
    traverse(else_statement->else_body);
    indent_counter--;
}

void translate_input(struct AST_Node_Input *input) {
    if (!input) return;
    char *value = translate_operand(input->input_op);
    fprintf(fptr, "%s = input()\n", value);
    free(value);
}

void translate_output(struct AST_Node_Output *output) {
    if (!output) return;

    char all_parts_buffer[2048]; 
    all_parts_buffer[0] = '\0';
    size_t current_buffer_len = 0;
    // bool first_part_for_concatenation = true; // Replaced by checking current_buffer_len

    struct AST_Node_Output *current_output = output;
    while (current_output != NULL) {
        if (current_output->output_op) {
            char *original_part_value = translate_operand(current_output->output_op);
            bool part_is_endl = false;

            if (current_output->output_op->operand_type == CONTENT_TYPE_ID && 
                original_part_value != NULL && 
                strcmp(original_part_value, "endl") == 0) {
                part_is_endl = true;
            }

            if (part_is_endl) {
                // ENDL: Handled by the final print() or print(concatenated_string) adding a newline.
                // Do not add anything to all_parts_buffer from endl itself.
            } else if (original_part_value) { 
                char *processed_part_value = NULL;
                switch (current_output->output_op->operand_type) {
                    case CONTENT_TYPE_ID:
                    case CONTENT_TYPE_EXPRESSION:
                        asprintf(&processed_part_value, "str(%s)", original_part_value);
                        break;
                    case CONTENT_TYPE_STRING: // Already quoted by translate_operand
                        processed_part_value = strdup(original_part_value);
                        break;
                    case CONTENT_TYPE_INT_NUMBER:
                    case CONTENT_TYPE_FLOAT_NUMBER:
                    case CONTENT_TYPE_BOOL: // translate_operand returns as string
                        processed_part_value = strdup(original_part_value);
                        break;
                    default:
                        processed_part_value = strdup("\"[UNTRANSLATED_OPERAND]\""); 
                        break;
                }
                
                if (processed_part_value) {
                    // Only add part if it is not an empty string that would become "str()"
                    if (strcmp(processed_part_value, "str()") == 0 && current_buffer_len > 0) {
                        // If it's str() and not the first item, skip it to avoid "... + str()"
                    } else if (strlen(processed_part_value) > 0 || strcmp(processed_part_value, "str()") != 0 ) {
                        // Add if it has content OR if it IS str() but it's the first part (buffer is empty)
                        size_t part_len = strlen(processed_part_value);
                        size_t plus_len = (current_buffer_len == 0) ? 0 : 3; // " + "

                        if (current_buffer_len + part_len + plus_len < sizeof(all_parts_buffer) - 1) {
                            if (current_buffer_len > 0) { // Not the first part
                                strcat(all_parts_buffer, " + ");
                                current_buffer_len += 3;
                            }
                            strcat(all_parts_buffer, processed_part_value);
                            current_buffer_len += part_len;
                        } else {
                            fprintf(stderr, "Warning: Output line too long for concatenation, may be truncated.\n");
                        }
                    }
                    free(processed_part_value); 
                }
            }
            if (original_part_value) free(original_part_value); 
        } 
        current_output = current_output->next_output;
    } 

    print_indent(indent_counter);
    if (strlen(all_parts_buffer) > 0) { 
        fprintf(fptr, "print(%s)\n", all_parts_buffer);
    } else {
        // This handles `cout << endl;` or if all parts effectively result in an empty buffer.
        fprintf(fptr, "print()\n"); 
    }
}

void translate_return(struct AST_Node_Return *return_node) {
    if (!return_node) return;
    print_indent(indent_counter);
    if (!return_node->value) {
        fprintf(fptr, "return None\n");
        g_return_has_been_emitted_for_current_func = true;
        return;
    }
    struct AST_Node *node_value = return_node->value;
    if (!node_value || !node_value->value) { // Added check for node_value->value
        fprintf(fptr, "return None\n");
        g_return_has_been_emitted_for_current_func = true;
        return;
    }
    struct AST_Node_Operand *operand = (struct AST_Node_Operand*)node_value->value;
    if (!operand) {
        fprintf(fptr, "return None\n");
        g_return_has_been_emitted_for_current_func = true;
        return;
    }
    char *value = translate_operand(operand);
    if (!value || strlen(value) == 0) {
        fprintf(fptr, "return None\n");
        if (value) free(value);
        g_return_has_been_emitted_for_current_func = true;
        return;
    }
    fprintf(fptr, "return %s\n", value);
    free(value);
    g_return_has_been_emitted_for_current_func = true;
    printf("[DEBUG] Translated return statement\n");
}

void translate_access_class(struct AST_Node_Object *access_class) {
    if (!access_class) return;
    fprintf(fptr, "%s.%s\n", access_class->obj_name, access_class->access_value.val);
}

void traverse_class_init(struct AST_Node_Statements *root) {
    if (!root) return;
    
    struct AST_Node_Statements *current = root;
    while (current) {
        if (current->left && current->left->n_type == INIT_NODE) {
            struct AST_Node_Init *init = current->left->value.init;
            
            print_indent(indent_counter);
            fprintf(fptr, "self.%s = ", init->assign->var);
            
            // Default initialization values based on data type
            switch (init->data_type) {
                case DATA_TYPE_INT:
                    fprintf(fptr, "0\n");
                    break;
                case DATA_TYPE_FLOAT:
                    fprintf(fptr, "0.0\n");
                    break;
                case DATA_TYPE_STRING:
                    fprintf(fptr, "\"\"\n");
                    break;
                case DATA_TYPE_BOOL:
                    fprintf(fptr, "False\n");
                    break;
                default:
                    fprintf(fptr, "None\n");
            }
        }
        current = current->right;
    }
}

void translate_func_call_obj(struct AST_Node_FunctionCall *func_call, char *obj_name) {
    if (!func_call) return;
    char *params = translate_params(func_call->params);
    fprintf(fptr, "%s.%s(%s)\n", obj_name, func_call->func_name, params);
    free(params);
}

void translate_public_class_func_def(struct AST_Node_FunctionDef *func_def) {
    if (!func_def) return;
    char *params = translate_params(func_def->params);
    
    // For class methods in Python, self should always be the first parameter
    if (params && strlen(params) > 0) {
        fprintf(fptr, "def %s(self, %s):\n", func_def->func_name, params);
    } else {
        fprintf(fptr, "def %s(self):\n", func_def->func_name);
    }
    
    free(params);
    indent_counter++;
    traverse(func_def->f_body->func_body);
    
    // Add appropriate return statement if needed
    if (func_def->return_type == DATA_TYPE_NONE) {
        print_indent(indent_counter);
        fprintf(fptr, "return None\n");
    }
    
    indent_counter--;
}

void translate_private_class_func_def(struct AST_Node_FunctionDef *func_def) {
    if (!func_def) return;
    char *params = translate_params(func_def->params);
    
    // For private class methods in Python, use _ prefix and self as first parameter
    if (params && strlen(params) > 0) {
        fprintf(fptr, "def _%s(self, %s):\n", func_def->func_name, params);
    } else {
        fprintf(fptr, "def _%s(self):\n", func_def->func_name);
    }
    
    free(params);
    indent_counter++;
    traverse(func_def->f_body->func_body);
    
    // Add appropriate return statement if needed
    if (func_def->return_type == DATA_TYPE_NONE) {
        print_indent(indent_counter);
        fprintf(fptr, "return None\n");
    }
    
    indent_counter--;
}

void traverse_class_private_func(struct AST_Node_Statements *root) {
    if (!root) return;
    if (root->left && root->left->n_type == FUNC_DEF_NODE) {
        translate_private_class_func_def(root->left->value.functionDef);
    }
    if (root->right) {
        traverse_class_private_func(root->right);
    }
}

void traverse_class_public_func(struct AST_Node_Statements *root) {
    if (!root) return;
    if (root->left && root->left->n_type == FUNC_DEF_NODE) {
        translate_public_class_func_def(root->left->value.functionDef);
    }
    if (root->right) {
        traverse_class_public_func(root->right);
    }
}

void translate_object_assign(struct AST_Node_Object *object) {
    if (!object) return;
    print_indent(indent_counter);
    fprintf(fptr, "%s = %s()\n", object->obj_name, object->obj_class->class_name);
}

void translate_object(struct AST_Node_Object *create_object) {
    if (!create_object) return;
    translate_object_assign(create_object);
}

void translate_assign(struct AST_Node_Assign *assign) {
    if (!assign) return;
    
    print_indent(indent_counter);
    
    if (assign->a_type == CONTENT_TYPE_EXPRESSION && assign->a_val.expr) {
        // Special handling for expressions
        struct AST_Node_Expression *expr = assign->a_val.expr;
        if (expr->left_op && expr->right_op) {
            char *left = translate_operand(expr->left_op);
            char *right = translate_operand(expr->right_op);
            fprintf(fptr, "%s = %s %s %s\n", assign->var, left, expr->op, right);
            free(left);
            free(right);
            return;
        }
    }
    
    // Standard handling for non-expression assignments
    struct AST_Node_Operand *operand = malloc(sizeof(struct AST_Node_Operand));
    if (!operand) {
        fprintf(fptr, "%s = None  # Error in translation\n", assign->var);
        return;
    }
    
    operand->operand_type = assign->a_type;
    if (assign->a_type == CONTENT_TYPE_ID || 
        assign->a_type == CONTENT_TYPE_INT_NUMBER || 
        assign->a_type == CONTENT_TYPE_FLOAT_NUMBER || 
        assign->a_type == CONTENT_TYPE_STRING || 
        assign->a_type == CONTENT_TYPE_BOOL) {
        memcpy(&operand->value, &assign->a_val, sizeof(union Value_sym));
        char *value = translate_operand(operand);
        fprintf(fptr, "%s = %s\n", assign->var, value ? value : "None");
        if (value) free(value);
    } else {
        fprintf(fptr, "%s = None  # Unsupported assignment type\n", assign->var);
    }
    
    free(operand);
}

void print_indent(int level) {
    for (int i = 0; i < level; i++) {
        fprintf(fptr, "    ");
    }
}

void translate_class(struct AST_Node_Class *create_class) {
    if (!create_class) return;
    fprintf(fptr, "class %s:\n", create_class->class_name);
    indent_counter++;

    // Handle public members
    if (create_class->c_body->pub_body) {
        traverse(create_class->c_body->pub_body);
    }

    // Handle private members
    if (create_class->c_body->pri_body) {
        // In Python, we prefix private members with double underscore
        struct AST_Node_Statements *private_stmts = create_class->c_body->pri_body;
        while (private_stmts) {
            if (private_stmts->left) {
                print_indent(indent_counter);
                fprintf(fptr, "__");  // Add double underscore for private members
                // Create a temporary statements node to traverse just this statement
                struct AST_Node_Statements *temp = malloc(sizeof(struct AST_Node_Statements));
                temp->left = private_stmts->left;
                temp->right = NULL;
                traverse(temp);
                free(temp);
            }
            private_stmts = private_stmts->right;
        }
    }

    indent_counter--;
}

void translate_class_child(struct AST_Node_Class *create_child) {
    if (!create_child) return;
    fprintf(fptr, "class %s(%s):\n", create_child->class_name, create_child->parent_class->class_name);
    indent_counter++;
    traverse_class_init(create_child->c_body->pri_body);
    traverse_class_init(create_child->c_body->pub_body);
    traverse_class_private_func(create_child->c_body->pri_body);
    traverse_class_public_func(create_child->c_body->pub_body);
    indent_counter--;
}

char *translate_assignment(struct AST_Node_Assign *assign) {
    if (!assign) return strdup("");
    
    char *result = NULL;
    char *var = assign->var;
    
    switch (assign->a_type) {
        case CONTENT_TYPE_INT_NUMBER:
        case CONTENT_TYPE_FLOAT_NUMBER:
        case CONTENT_TYPE_STRING:
        case CONTENT_TYPE_BOOL:
            asprintf(&result, "%s = %s", var, assign->a_val.val);
            break;
        case CONTENT_TYPE_ID:
            asprintf(&result, "%s = %s", var, assign->a_val.val);
            break;
        case CONTENT_TYPE_EXPRESSION: {
            struct AST_Node_Expression *expr = assign->a_val.expr;
            if (!expr) {
                asprintf(&result, "%s = None # Invalid expression", var);
                break;
            }
            
            // Handle increment/decrement operators
            if (strcmp(expr->op, "+=") == 0 && strcmp(expr->right_op->value.val, "1") == 0) {
                asprintf(&result, "%s += 1", var);
            } else if (strcmp(expr->op, "-=") == 0 && strcmp(expr->right_op->value.val, "1") == 0) {
                asprintf(&result, "%s -= 1", var);
            } else {
                char *expr_str = translate_operand(assign->a_val.expr);
                asprintf(&result, "%s = %s", var, expr_str);
                free(expr_str);
            }
            break;
        }
        default:
            asprintf(&result, "%s = None # Unknown assignment type", var);
            break;
    }
    
    return result;
} 