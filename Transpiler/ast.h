#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

// Memory tracking macros
#ifdef DEBUG_MEMORY
#define MALLOC(size) ({ \
    void *ptr = malloc(size); \
    printf("[DEBUG] malloc(%zu) = %p\n", size, ptr); \
    ptr; \
})
#define FREE(ptr) ({ \
    printf("[DEBUG] free(%p)\n", ptr); \
    free(ptr); \
})
#else
#define MALLOC(size) malloc(size)
#define FREE(ptr) free(ptr)
#endif

/****************** Data Types *****************/ 

// TYPE OF SYMBOLS
typedef enum {
    SYMBOL_VARIABLE,
    SYMBOL_CONTENT,
    SYMBOL_FUNCTION,
    SYMBOL_CLASS,
    SYMBOL_OBJECT,
    SYMBOL_PARAMETER
} SYMBOL_TYPE;

// Data types
typedef enum {
    DATA_TYPE_NONE,
    DATA_TYPE_INT,
    DATA_TYPE_FLOAT,
    DATA_TYPE_STRING,
    DATA_TYPE_BOOL
} DATA_TYPE;

/****************** Node Types *****************/ 

union yystype {
    char *string;
    struct AST_Node_Assign          *assign;
    struct AST_Node_Declare_Params  *declare_params;
    struct AST_Node_Params          *params;
    struct AST_Node_Instruction     *instruction;
    struct AST_Node_Expression      *expression;
    struct AST_Node_Statements      *statements;
    struct AST_Node_Value           *value;
    struct AST_Node_Variable        *variable;
    struct AST_Node_Init            *init;
    struct AST_Node_FunctionCall    *functionCall;
    struct AST_Node_FunctionDef     *functionDef;
    struct AST_Node_If              *ifNode;
    struct AST_Node_Else            *elseNode;
    struct AST_Node_Else_If         *elseIfNode;
    struct AST_Node_For             *forNode;
    struct AST_Node_Operand         *operand;
    struct AST_Node_Return          *returnNode;
    struct AST_Node_Input           *inputNode;
    struct AST_Node_Output          *outputNode;
    struct AST_Node_FBody           *FBodyNode;
    struct AST_Node_Class           *classNode;
    struct AST_Node_CBody           *CBodyNode;
    struct AST_Node_Object          *objectNode;
    int data_type;
};

// Node types
typedef enum {
    PROGRAM_NODE,
    STATEMENTS_NODE,
    INSTRUCTION_NODE,
    FUNC_DEF_NODE,
    FUNC_CALL_NODE,
    IF_NODE,
    ELSE_IF_NODE,
    ELSE_NODE,
    FOR_NODE,
    ASSIGN_NODE,
    INIT_NODE,
    EXPRESSION_NODE,
    OPERAND_NODE,
    RETURN_NODE,
    INPUT_NODE,
    OUTPUT_NODE,
    CLASS_NODE,
    CLASS_CHILD_NODE,
    OBJECT_NODE,
    ACCESS_CLASS_NODE,
    PARAMS_NODE,
    F_BODY_NODE,
    C_BODY_NODE,
    PARENT_PUBLIC_NODE,
    PRINT_NODE,
    BIN_OP_NODE,
    UN_OP_NODE,
    NUM_NODE,
    FLOAT_NODE,
    STRING_NODE,
    BOOL_NODE,
    VAR_NODE,
    BREAK_NODE,
    CONTINUE_NODE,
    OBJ_CALL_NODE,
    CLASS_DEF_NODE,
    WHILE_NODE
} NODE_TYPE;

// Content types
typedef enum {
    CONTENT_TYPE_ID,
    CONTENT_TYPE_INT_NUMBER,
    CONTENT_TYPE_FLOAT_NUMBER,
    CONTENT_TYPE_STRING,
    CONTENT_TYPE_BOOL,
    CONTENT_TYPE_FUNCTION,
    CONTENT_TYPE_EXPRESSION
} CONTENT_TYPE;

// Access types
typedef enum {
    ACCESS_TYPE_VAR,
    ACCESS_TYPE_FUNCTION,
    ACCESS_TYPE_ASSIGN
} ACCESS_TYPE;

/* ---------------------COMPLEX TYPES-------------------------- */

// TODO DA USARE CON AST_Node_Value 
typedef union Value_sym {
    char *val;
    struct AST_Node_Expression *expr;
    struct AST_Node_FunctionCall *funca; 
    struct AST_Node_Assign  *ass_val;
};

static union Value_sym null_value;

// Forward declarations
struct AST_Node_Statements;
struct AST_Node_Instruction;
struct AST_Node_FunctionCall;
struct AST_Node_FunctionDef;
struct AST_Node_Class;
struct AST_Node_CBody;
struct AST_Node_If;
struct AST_Node_Else_If;
struct AST_Node_Else;
struct AST_Node_For;
struct AST_Node_Expression;
struct AST_Node_Operand;
struct AST_Node_Input;
struct AST_Node_Output;
struct AST_Node_Assign;
struct AST_Node_Init;
struct AST_Node_Params;
struct AST_Node_FBody;
struct AST_Node_Object;
struct AST_Node_Parent_Public;
struct AST_Node_BinOp;
struct AST_Node_UnOp;
struct AST_Node_Num;
struct AST_Node_Float;
struct AST_Node_String;
struct AST_Node_Bool;
struct AST_Node_Var;
struct AST_Node_NoOp;
struct AST_Node_Print;
struct AST_Node_Return;
struct AST_Node_Break;
struct AST_Node_Continue;
struct AST_Node_ClassDef;
struct AST_Node_ObjectCall;

// Node structures
struct AST_Node_Statements {
    NODE_TYPE n_type;
    struct AST_Node_Instruction *left;
    struct AST_Node_Statements *right;
};

struct AST_Node_Instruction {
    NODE_TYPE n_type;
    union yystype value;
};

/* ----------------------------INITIALIZATION NODE--------------------------------------- */

struct AST_Node_Init{
    DATA_TYPE data_type;
    struct AST_Node_Assign *assign;
    struct AST_Node_Init *next_init;
};

struct AST_Node_Assign { 
    char *var;
    DATA_TYPE val_type;
    union Value_sym a_val;
    CONTENT_TYPE a_type;
};

struct AST_Node_FunctionCall{
    char *func_name;
    struct AST_Node_Params *params;  // parametri funzione
    DATA_TYPE return_type;
};

struct AST_Node_FunctionDef{
    char *func_name;
    struct AST_Node_Params *params;  // parametri funzione
    DATA_TYPE return_type;
    struct AST_Node_FBody *f_body;
    bool is_class_method;  // Flag to indicate if this is a class method
};

struct AST_Node_Params{
    struct AST_Node_Init    *decl_param;    // da usare in dichiarazione di funzione
    struct AST_Node_Operand *call_param;    // da usare solo nella chiamata di funzione
    struct AST_Node_Params  *next_param;

};

struct AST_Node_If{
    struct AST_Node_Expression *condition;
    struct AST_Node_Statements *if_body;
    struct AST_Node_Else_If *else_if;
    struct AST_Node_Else *else_body;
};

struct AST_Node_Else_If{
    struct AST_Node_Expression *condition;
    struct AST_Node_Statements *elif_body;
};

struct AST_Node_Else{
    struct AST_Node_Statements *else_body;
};

struct AST_Node_Operand {
    union Value_sym value;
    DATA_TYPE val_type;
    CONTENT_TYPE operand_type;
};

struct AST_Node_For{
    struct AST_Node_Assign *init;
    struct AST_Node_Expression *condition;
    struct AST_Node_Assign *increment;
    struct AST_Node_Statements *for_body;
};

struct AST_Node_Expression{
    DATA_TYPE expr_type;
    char *op;
    struct AST_Node_Operand *left_op;  // left operand
	struct AST_Node_Operand *right_op; // right operand
    
};

struct AST_Node_Input{
    struct AST_Node_Operand  *input_op;
    struct AST_Node_Input *next_input;
};

struct AST_Node_Output {
    struct AST_Node_Operand *output_op;
    struct AST_Node_Output *next_output;
};

struct AST_Node_FBody {
    struct AST_Node_Statements *func_body;
    struct AST_Node_Operand *return_op;

};

struct AST_Node_Class {
    char *class_name;
    struct AST_Node_CBody *c_body;
    struct AST_Node_Class *parent_class;
    struct AST_Node_Parent_Public *parent_class_public;
};


struct AST_Node_CBody {
    struct AST_Node_Statements *pri_body;
    struct AST_Node_Statements *pub_body;
};

struct AST_Node_Parent_Public {
    struct AST_Node_Statements      *parent_pub_body;
    struct AST_Node_Parent_Public   *next_parent_public;

};

struct AST_Node_Object {
    char *obj_name;
    union Value_sym access_value;
    struct AST_Node_Class *obj_class;
    ACCESS_TYPE access_type;
};

// Generic AST node
struct AST_Node {
    NODE_TYPE n_type;
    void *value;
};

// Binary operation node
struct AST_Node_BinOp {
    struct AST_Node *left;
    char *op;
    struct AST_Node *right;
};

// Unary operation node
struct AST_Node_UnOp {
    char *op;
    struct AST_Node *operand;
};

// Number node
struct AST_Node_Num {
    int value;
};

// Float node
struct AST_Node_Float {
    float value;
};

// String node
struct AST_Node_String {
    char *value;
};

// Boolean node
struct AST_Node_Bool {
    bool value;
};

// Variable node
struct AST_Node_Var {
    char *name;
};

// No operation node
struct AST_Node_NoOp {
    // No fields needed
};

// Print node (used for output)
struct AST_Node_Print {
    struct AST_Node *value;
};

// Return node
struct AST_Node_Return {
    struct AST_Node *value;
};

// Break node
struct AST_Node_Break {
    // No fields needed
};

// Continue node
struct AST_Node_Continue {
    // No fields needed
};

// Class definition node (for compatibility with ast.c)
struct AST_Node_ClassDef {
    char *class_name;
    struct AST_Node_Statements *body;
};

// Object call node (for compatibility with ast.c)
struct AST_Node_ObjectCall {
    char *obj_name;
    char *func_name;
    struct AST_Node_Params *params;
};

// Parameter node (for compatibility with ast.c)
struct AST_Node_Param {
    char *param_name;
    DATA_TYPE data_type;
};

// Parameter declaration node (for compatibility with ast.c)
struct AST_Node_ParamDecl {
    char *param_name;
    DATA_TYPE data_type;
};

// Parameter call node (for compatibility with ast.c)
struct AST_Node_ParamCall {
    struct AST_Node *value;
};

// While node
struct AST_Node_While {
    struct AST_Node *condition;
    struct AST_Node_Statements *body;
};

#endif
