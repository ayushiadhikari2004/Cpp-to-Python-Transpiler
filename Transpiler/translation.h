#define _GNU_SOURCE
#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>

extern int indent_counter;       // global variable to keep track of indentation
extern FILE *fptr;         // global file pointer for translation

/*************** FUNCTION DECLARATION ****************/
char* python_type(DATA_TYPE type);
char* node_type(NODE_TYPE type);
void traverse(struct AST_Node_Statements *root);
void translate_init(struct AST_Node_Init *init);
void translate_func_call(struct AST_Node_FunctionCall *func_call);
void translate_func_def(struct AST_Node_FunctionDef *func_def);
void translate_expr(struct AST_Node_Expression *expr);
void translate_if(struct AST_Node_If *if_statement);
void translate_else_if(struct AST_Node_Else_If *else_if_statement);
void translate_else(struct AST_Node_Else *else_statement);
void translate_for(struct AST_Node_For *for_loop);
void translate_input(struct AST_Node_Input *input);
void translate_output(struct AST_Node_Output *output);
void translate_return(struct AST_Node_Return *return_node);
void translate_access_class(struct AST_Node_Object *access_class);
void traverse_class_init(struct AST_Node_Statements *root);
void translate_func_call_obj(struct AST_Node_FunctionCall *func_call,char *obj_name);
void translate_public_class_func_def(struct AST_Node_FunctionDef *func_def);
void traverse_class_private_init(struct AST_Node_Statements *root);
void traverse_class_public_init(struct AST_Node_Statements *root);
void traverse_class_private_func(struct AST_Node_Statements *root);
void traverse_class_public_func(struct AST_Node_Statements *root);
void translate_object_assign(struct AST_Node_Object *object);
void translate_private_class_func_def(struct AST_Node_FunctionDef *func_def);
char* translate_ast_node(struct AST_Node *node);
char* translate_params(struct AST_Node_Params *params);
char* translate_operand(struct AST_Node_Operand *operand);
char* translate_statements(struct AST_Node_Statements *statements, int indent_level);
char* translate_instruction(struct AST_Node_Instruction *instr, int indent_level);
void translate_class(struct AST_Node_Class *create_class);
void translate_class_child(struct AST_Node_Class *create_child);
void translate_object(struct AST_Node_Object *create_object);
void translate_assign(struct AST_Node_Assign *assign);
void print_indent(int level);
