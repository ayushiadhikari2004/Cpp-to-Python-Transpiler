#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Create new AST node
struct AST_Node *new_ast_node(NODE_TYPE n_type, void *value) {
    struct AST_Node *node = (struct AST_Node *)malloc(sizeof(struct AST_Node));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for AST node\n");
        return NULL;
    }
    
    node->n_type = n_type;
    node->value = value;
    return node;
}

// Create new instruction node
struct AST_Node_Instruction *new_instruction_node(NODE_TYPE n_type, void *value) {
    struct AST_Node_Instruction *node = (struct AST_Node_Instruction *)malloc(sizeof(struct AST_Node_Instruction));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for instruction node\n");
        return NULL;
    }
    
    node->n_type = n_type;
    node->value.instruction = (struct AST_Node_Instruction *)value;  // Cast to the appropriate type
    return node;
}

// Create new statements node
struct AST_Node_Statements *new_statements_node(struct AST_Node_Instruction *left, struct AST_Node_Statements *right) {
    struct AST_Node_Statements *node = (struct AST_Node_Statements *)malloc(sizeof(struct AST_Node_Statements));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for statements node\n");
        return NULL;
    }
    
    node->left = left;
    node->right = right;
    return node;
}

// Create new function definition node
struct AST_Node_FunctionDef *new_function_def_node(char *func_name, DATA_TYPE ret_type, 
                                                 struct AST_Node_Params *params,
                                                 struct AST_Node_Statements *body) {
    struct AST_Node_FunctionDef *node = (struct AST_Node_FunctionDef *)malloc(sizeof(struct AST_Node_FunctionDef));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for function definition node\n");
        return NULL;
    }
    
    node->func_name = strdup(func_name);
    node->return_type = ret_type;
    node->params = params;
    node->f_body = (struct AST_Node_FBody *)body;  // Cast to correct type
    return node;
}

// Create new function call node
struct AST_Node_FunctionCall *new_function_call_node(char *func_name, struct AST_Node_Params *params) {
    struct AST_Node_FunctionCall *node = (struct AST_Node_FunctionCall *)malloc(sizeof(struct AST_Node_FunctionCall));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for function call node\n");
        return NULL;
    }
    
    node->func_name = strdup(func_name);
    node->params = params;
    return node;
}

// Create new parameter node
struct AST_Node_Params *new_params_node(struct AST_Node_Param *param, struct AST_Node_Params *next) {
    struct AST_Node_Params *node = (struct AST_Node_Params *)malloc(sizeof(struct AST_Node_Params));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for parameters node\n");
        return NULL;
    }
    
    node->decl_param = (struct AST_Node_Init *)param;  // Cast to correct type
    node->next_param = next;
    return node;
}

// Create new parameter declaration node
struct AST_Node_ParamDecl *new_param_decl_node(char *param_name, DATA_TYPE data_type) {
    struct AST_Node_ParamDecl *node = (struct AST_Node_ParamDecl *)malloc(sizeof(struct AST_Node_ParamDecl));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for parameter declaration node\n");
        return NULL;
    }
    
    node->param_name = strdup(param_name);
    node->data_type = data_type;
    return node;
}

// Create new parameter call node
struct AST_Node_ParamCall *new_param_call_node(struct AST_Node *value) {
    struct AST_Node_ParamCall *node = (struct AST_Node_ParamCall *)malloc(sizeof(struct AST_Node_ParamCall));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for parameter call node\n");
        return NULL;
    }
    
    node->value = value;
    return node;
}

// Create new initialization node
struct AST_Node_Init *new_init_node(struct AST_Node_Assign *assign) {
    struct AST_Node_Init *node = (struct AST_Node_Init *)malloc(sizeof(struct AST_Node_Init));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for initialization node\n");
        return NULL;
    }
    
    node->assign = assign;
    return node;
}

// Create new assignment node
struct AST_Node_Assign *new_assign_node(char *var, struct AST_Node *value) {
    struct AST_Node_Assign *node = (struct AST_Node_Assign *)malloc(sizeof(struct AST_Node_Assign));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for assignment node\n");
        return NULL;
    }
    
    node->var = strdup(var);
    node->a_val.expr = (struct AST_Node_Expression *)value;  // Cast to the appropriate type
    return node;
}

// Create new class definition node
struct AST_Node_ClassDef *new_class_def_node(char *class_name, struct AST_Node_Statements *body) {
    struct AST_Node_ClassDef *node = (struct AST_Node_ClassDef *)malloc(sizeof(struct AST_Node_ClassDef));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for class definition node\n");
        return NULL;
    }
    
    node->class_name = strdup(class_name);
    node->body = body;
    return node;
}

// Create new object node
struct AST_Node_Object *new_object_node(char *class_name, char *obj_name) {
    struct AST_Node_Object *node = (struct AST_Node_Object *)malloc(sizeof(struct AST_Node_Object));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for object node\n");
        return NULL;
    }
    
    node->obj_name = strdup(obj_name);
    node->obj_class = (struct AST_Node_Class *)malloc(sizeof(struct AST_Node_Class));
    node->obj_class->class_name = strdup(class_name);
    return node;
}

// Create new object call node
struct AST_Node_ObjectCall *new_object_call_node(char *obj_name, char *func_name, struct AST_Node_Params *params) {
    struct AST_Node_ObjectCall *node = (struct AST_Node_ObjectCall *)malloc(sizeof(struct AST_Node_ObjectCall));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for object call node\n");
        return NULL;
    }
    
    node->obj_name = strdup(obj_name);
    node->func_name = strdup(func_name);
    node->params = params;
    return node;
}

// Create new if node
struct AST_Node_If *new_if_node(struct AST_Node *condition, struct AST_Node_Statements *body) {
    struct AST_Node_If *node = (struct AST_Node_If *)malloc(sizeof(struct AST_Node_If));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for if node\n");
        return NULL;
    }
    
    node->condition = (struct AST_Node_Expression *)condition;  // Cast to correct type
    node->if_body = body;
    return node;
}

// Create new while node
struct AST_Node_While *new_while_node(struct AST_Node *condition, struct AST_Node_Statements *body) {
    struct AST_Node_While *node = (struct AST_Node_While *)malloc(sizeof(struct AST_Node_While));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for while node\n");
        return NULL;
    }
    
    node->condition = condition;
    node->body = body;
    return node;
}

// Create new for node
struct AST_Node_For *new_for_node(struct AST_Node_Assign *init, struct AST_Node_Expression *condition, struct AST_Node_Assign *increment, struct AST_Node_Statements *for_body) {
    struct AST_Node_For *node = (struct AST_Node_For *)malloc(sizeof(struct AST_Node_For));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for for node\n");
        return NULL;
    }
    node->init = init;
    node->condition = condition;
    node->increment = increment;
    node->for_body = for_body;
    return node;
}

// Create new print node
struct AST_Node_Print *new_print_node(struct AST_Node *value) {
    struct AST_Node_Print *node = (struct AST_Node_Print *)malloc(sizeof(struct AST_Node_Print));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for print node\n");
        return NULL;
    }
    
    node->value = value;
    return node;
}

// Create new return node
struct AST_Node_Return *new_return_node(struct AST_Node *value) {
    struct AST_Node_Return *node = (struct AST_Node_Return *)malloc(sizeof(struct AST_Node_Return));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for return node\n");
        return NULL;
    }
    
    node->value = value;
    return node;
}

// Create new break node
struct AST_Node_Break *new_break_node(void) {
    struct AST_Node_Break *node = (struct AST_Node_Break *)malloc(sizeof(struct AST_Node_Break));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for break node\n");
        return NULL;
    }
    
    return node;
}

// Create new continue node
struct AST_Node_Continue *new_continue_node(void) {
    struct AST_Node_Continue *node = (struct AST_Node_Continue *)malloc(sizeof(struct AST_Node_Continue));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for continue node\n");
        return NULL;
    }
    
    return node;
}

// Create new binary operation node
struct AST_Node_BinOp *new_binop_node(struct AST_Node *left, char *op, struct AST_Node *right) {
    struct AST_Node_BinOp *node = (struct AST_Node_BinOp *)malloc(sizeof(struct AST_Node_BinOp));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for binary operation node\n");
        return NULL;
    }
    
    node->left = left;
    node->op = strdup(op);
    node->right = right;
    return node;
}

// Create new unary operation node
struct AST_Node_UnOp *new_unop_node(char *op, struct AST_Node *operand) {
    struct AST_Node_UnOp *node = (struct AST_Node_UnOp *)malloc(sizeof(struct AST_Node_UnOp));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for unary operation node\n");
        return NULL;
    }
    
    node->op = strdup(op);
    node->operand = operand;
    return node;
}

// Create new number node
struct AST_Node_Num *new_num_node(int value) {
    struct AST_Node_Num *node = (struct AST_Node_Num *)malloc(sizeof(struct AST_Node_Num));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for number node\n");
        return NULL;
    }
    
    node->value = value;
    return node;
}

// Create new float node
struct AST_Node_Float *new_float_node(float value) {
    struct AST_Node_Float *node = (struct AST_Node_Float *)malloc(sizeof(struct AST_Node_Float));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for float node\n");
        return NULL;
    }
    
    node->value = value;
    return node;
}

// Create new string node
struct AST_Node_String *new_string_node(char *value) {
    struct AST_Node_String *node = (struct AST_Node_String *)malloc(sizeof(struct AST_Node_String));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for string node\n");
        return NULL;
    }
    
    node->value = strdup(value);
    return node;
}

// Create new boolean node
struct AST_Node_Bool *new_bool_node(bool value) {
    struct AST_Node_Bool *node = (struct AST_Node_Bool *)malloc(sizeof(struct AST_Node_Bool));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for boolean node\n");
        return NULL;
    }
    
    node->value = value;
    return node;
}

// Create new variable node
struct AST_Node_Var *new_var_node(char *name) {
    struct AST_Node_Var *node = (struct AST_Node_Var *)malloc(sizeof(struct AST_Node_Var));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for variable node\n");
        return NULL;
    }
    
    node->name = strdup(name);
    return node;
}

// Create new no operation node
struct AST_Node_NoOp *new_noop_node(void) {
    struct AST_Node_NoOp *node = (struct AST_Node_NoOp *)malloc(sizeof(struct AST_Node_NoOp));
    if (!node) {
        fprintf(stderr, "Error: Failed to allocate memory for no operation node\n");
        return NULL;
    }
    
    return node;
} 
