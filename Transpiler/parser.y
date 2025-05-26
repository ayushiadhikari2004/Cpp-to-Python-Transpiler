%{
/****************** Prologue *****************/ 
	#include <math.h>
	#include <stdio.h>
	#include <ctype.h>
    #include <string.h>
	#include "symtab.h"
    #include "ast.h" 
    #include "translation.h"
    #include "utils.h"
    #include <stdbool.h>

    int yylex (void);
    int yyerror(char *s);
    int n_error = 0;
    extern int yylineno;
    extern FILE *yyin;
    // Pointer to file used for translation
    FILE *fptr;

/****************** Initialization of structs, counters and variables*****************/ 
    struct AST_Node_Statements  *root;
    struct SymTab *local_table  = NULL; 
    struct AST_Node_Class       *class_array[100]       = { NULL };
    struct AST_Node_Object      *object_array[100]      = { NULL };
    struct AST_Node_FunctionDef *function_array[100]    = { NULL };
    int class_counter = 0;
    int object_counter = 0;
    int function_counter = 0;
    bool found = false;
    bool in_class = false;
    // This is a helper function to distinguish class methods from regular functions
    bool is_inside_class = false;

    // Add cleanup function
    void cleanup_arrays() {
        for (int i = 0; i < class_counter; i++) {
            if (class_array[i] != NULL) {
                free(class_array[i]);
                class_array[i] = NULL;
            }
        }
        for (int i = 0; i < object_counter; i++) {
            if (object_array[i] != NULL) {
                free(object_array[i]);
                object_array[i] = NULL;
            }
        }
        for (int i = 0; i < function_counter; i++) {
            if (function_array[i] != NULL) {
                free(function_array[i]);
                function_array[i] = NULL;
            }
        }
        class_counter = 0;
        object_counter = 0;
        function_counter = 0;
    }

/****************** functions declaration *****************/ 
    bool search_class_body(char* var_name, struct AST_Node_Statements *root);
    void check_function_call(struct AST_Node_FunctionCall *func_call);
    char * type_to_str(int type);
    void scope_enter();
    void scope_exit();
    
%}

    //%define parse.error verbose
    //%debug

    %token SEMICOLON
	%token IF 
	%token ELSE
	%token ID
	%token INT_NUMBER   
	%token FLOAT_NUMBER
    %token INT
	%token FLOAT
	%token STRING
	%token BOOL
    %token LPAR
    %token RPAR
    %token LBRACE
    %token RBRACE
    %token COLON
    %token COMMA
    %token DOT
    %token BRACKETS
	%token RETURN
	%token COUT
	%token CIN
	%token STRING_V
    %token BOOL_V
	%token FOR
    %token FUNCTION
    %token CLASS
    %token MAIN
    %token PRIVATE
    %token PUBLIC
    %token UNKNOWN
    %token EQ AND OR ADD SUB MUL DIV GT LT GE LE EEQ NE INC DEC
    %token LSHIFT RSHIFT
 
/****************** types *****************/ 
    %define api.value.type {union yystype}

    %type <string>          ID STRING FLOAT_NUMBER INT_NUMBER FLOAT INT BOOL LPAR RPAR LBRACE RBRACE COLON SEMICOLON COMMA DOT BRACKETS RETURN COUT CIN STRING_V BOOL_V FOR FUNCTION CLASS UNKNOWN AND OR ADD SUB MUL DIV GT LT GE LE EEQ NE MAIN PRIVATE PUBLIC EQ INC DEC
    %type <statements>      statements body program sections section
    %type <instruction>    statement
    %type <functionCall>    function_call
    %type <functionDef>     function_def
    %type <params>          multi_fun_param fun_param  
    %type <ifNode>          if_statement
    %type <expression>      if_condition expr math_expr logic_expr rel_expr 
    %type <elseIfNode>      else_if_statement
    %type <elseNode>        else_statement
    %type <forNode>         for_loop
    %type <inputNode>       single_rshift multi_rshift input_stmnt
    %type <outputNode>      multi_lshift output_stmnt
    %type <assign>          assignment
    %type <init>            initialization 
    %type <operand>         content single_lshift
    %type <FBodyNode>       func_body
    %type <classNode>       create_class create_class_child
    %type <CBodyNode>       class_body
    %type <objectNode>      create_object access_class
    %type <data_type> types

    %start program
%%  

    program:   { 
        debug_print("Entering program rule", NULL);
        scope_enter(); 
    }    statements    { 
        debug_print("Creating program node", NULL);
        root = (struct AST_Node_Statements*)$2; 
        scope_exit(); 
        debug_print("Program node created", NULL);
    };


    statements:
            /* empty */
            { $$ = NULL; }
        |   statement statements
            {
                debug_print("Appending statement to statements", NULL);
                struct AST_Node_Statements *node = (struct AST_Node_Statements*)malloc(sizeof(struct AST_Node_Statements));
                node->left = $1;
                node->right = $2;
                $$ = node;
                debug_print("Statement appended", $$);
            }
        ;


    statement:
            function_def 
            { 
                debug_print("Creating statement from function_def", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = FUNC_DEF_NODE;
                $$->value.functionDef = $1;
                struct Symbol *s = find_symtab($1->func_name, local_table);
                if (s == NULL) {
                    s = add_symbol($1->func_name, local_table, SYMBOL_FUNCTION, DATA_TYPE_NONE, $1->return_type, true, NULL, false, yylineno, null_value);
                    debug_print("Function symbol added", s);
                } else {
                    printf("\n\n\t***Error: %s already declared***\n\t***Line: %d***\n\n\n", s->name_sym, yylineno);
                    n_error++;
                }
                debug_print("Function statement created", $$);
            }
            // Parse short-form function declaration inside a class
            | types ID LPAR RPAR LBRACE ID EQ ID SEMICOLON COUT LSHIFT STRING_V LSHIFT ID SEMICOLON RETURN ID SEMICOLON RBRACE
            {
                if (is_inside_class) {
                    debug_print("Creating class method with inline body", NULL);
                    $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                    $$->n_type = FUNC_DEF_NODE;
                    
                    // Create the function def
                    struct AST_Node_FunctionDef *func_def = malloc(sizeof(struct AST_Node_FunctionDef));
                    func_def->func_name = $2;
                    func_def->params = NULL;
                    func_def->return_type = $1;
                    func_def->is_class_method = true;
                    
                    // Create function body manually
                    struct AST_Node_FBody *f_body = malloc(sizeof(struct AST_Node_FBody));
                    
                    // Create statement for assignment
                    struct AST_Node_Instruction *assign_instr = malloc(sizeof(struct AST_Node_Instruction));
                    assign_instr->n_type = ASSIGN_NODE;
                    struct AST_Node_Assign *assign = malloc(sizeof(struct AST_Node_Assign));
                    assign->var = $6;
                    assign->val_type = DATA_TYPE_INT;
                    assign->a_val.val = $8;
                    assign_instr->value.assign = assign;
                    
                    // Create statement for cout
                    struct AST_Node_Instruction *cout_instr = malloc(sizeof(struct AST_Node_Instruction));
                    cout_instr->n_type = OUTPUT_NODE;
                    struct AST_Node_Output *output = malloc(sizeof(struct AST_Node_Output));
                    struct AST_Node_Operand *cout_op = malloc(sizeof(struct AST_Node_Operand));
                    cout_op->operand_type = CONTENT_TYPE_STRING;
                    cout_op->val_type = DATA_TYPE_STRING;
                    cout_op->value.val = $12;
                    output->output_op = cout_op;
                    cout_instr->value.outputNode = output;
                    
                    // Create statements structure
                    struct AST_Node_Statements *stmt1 = malloc(sizeof(struct AST_Node_Statements));
                    stmt1->left = assign_instr;
                    struct AST_Node_Statements *stmt2 = malloc(sizeof(struct AST_Node_Statements));
                    stmt2->left = cout_instr;
                    stmt1->right = stmt2;
                    
                    f_body->func_body = stmt1;
                    
                    // Create return statement
                    struct AST_Node_Operand *return_op = malloc(sizeof(struct AST_Node_Operand));
                    return_op->operand_type = CONTENT_TYPE_ID;
                    return_op->val_type = $1;
                    return_op->value.val = $16;
                    f_body->return_op = return_op;
                    
                    func_def->f_body = f_body;
                    
                    // Store in function array
                    function_array[function_counter] = func_def;
                    function_counter++;
                    
                    $$->value.functionDef = func_def;
                    
                    // Add to symbol table
                    struct Symbol *s = find_symtab(func_def->func_name, local_table);
                    if (s == NULL) {
                        s = add_symbol(func_def->func_name, local_table, SYMBOL_FUNCTION, DATA_TYPE_NONE, func_def->return_type, true, NULL, false, yylineno, null_value);
                        debug_print("Class method symbol added", s);
                    } else {
                        printf("\n\n\t***Error: %s already declared***\n\t***Line: %d***\n\n\n", s->name_sym, yylineno);
                        n_error++;
                    }
                } else {
                    printf("\n\n\t***Error: Inline function declaration only allowed inside class***\n\t***Line: %d***\n\n\n", yylineno);
                    n_error++;
                }
            }
        |   RETURN content SEMICOLON
            {
                debug_print("Creating statement from return content", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = RETURN_NODE;
                struct AST_Node_Return *return_node = (struct AST_Node_Return*)malloc(sizeof(struct AST_Node_Return));
                struct AST_Node *operand_node = (struct AST_Node *)malloc(sizeof(struct AST_Node));
                operand_node->n_type = OPERAND_NODE;
                operand_node->value = $2;
                return_node->value = operand_node;
                $$->value.returnNode = return_node;
                debug_print("Return content statement created", $$);
            }
        |   RETURN expr SEMICOLON
            {
                debug_print("Creating statement from return expression", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = RETURN_NODE;
                struct AST_Node_Return *return_node = (struct AST_Node_Return*)malloc(sizeof(struct AST_Node_Return));
                
                // Create an operand for the expression
                struct AST_Node_Operand *expr_operand = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                expr_operand->value.expr = $2;
                expr_operand->val_type = $2->expr_type;
                expr_operand->operand_type = CONTENT_TYPE_EXPRESSION;
                
                struct AST_Node *operand_node = (struct AST_Node *)malloc(sizeof(struct AST_Node));
                operand_node->n_type = OPERAND_NODE;
                operand_node->value = expr_operand;
                
                return_node->value = operand_node;
                $$->value.returnNode = return_node;
                debug_print("Return expression statement created", $$);
            }
        |   if_statement 
            {
                debug_print("Creating statement from if_statement", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = IF_NODE;
                $$->value.ifNode = $1;
                debug_print("If statement created", $$);
            }
        |   for_loop 
            {
                debug_print("Creating statement from for_loop", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = FOR_NODE;
                $$->value.forNode = $1;
                debug_print("For loop created", $$);
            }
        |   ID INC SEMICOLON
            {
                debug_print("Creating increment statement", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = ASSIGN_NODE;
                struct AST_Node_Assign *assign = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                assign->var = $1;
                assign->val_type = DATA_TYPE_INT;
                assign->a_type = CONTENT_TYPE_EXPRESSION;
                
                struct AST_Node_Expression *expr = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                expr->op = "+";
                
                struct AST_Node_Operand *left = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                left->operand_type = CONTENT_TYPE_ID;
                left->value.val = $1;
                left->val_type = DATA_TYPE_INT;
                expr->left_op = left;
                
                struct AST_Node_Operand *right = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                right->operand_type = CONTENT_TYPE_INT_NUMBER;
                right->value.val = "1";
                right->val_type = DATA_TYPE_INT;
                expr->right_op = right;
                
                expr->expr_type = DATA_TYPE_INT;
                assign->a_val.expr = expr;
                $$->value.assign = assign;
            }
        |   ID DEC SEMICOLON
            {
                debug_print("Creating decrement statement", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = ASSIGN_NODE;
                struct AST_Node_Assign *assign = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                assign->var = $1;
                assign->val_type = DATA_TYPE_INT;
                assign->a_type = CONTENT_TYPE_EXPRESSION;
                
                struct AST_Node_Expression *expr = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                expr->op = "-";
                
                struct AST_Node_Operand *left = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                left->operand_type = CONTENT_TYPE_ID;
                left->value.val = $1;
                left->val_type = DATA_TYPE_INT;
                expr->left_op = left;
                
                struct AST_Node_Operand *right = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                right->operand_type = CONTENT_TYPE_INT_NUMBER;
                right->value.val = "1";
                right->val_type = DATA_TYPE_INT;
                expr->right_op = right;
                
                expr->expr_type = DATA_TYPE_INT;
                assign->a_val.expr = expr;
                $$->value.assign = assign;
            }
        |   assignment SEMICOLON 
            {
                debug_print("Creating statement from assignment", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = ASSIGN_NODE;
                struct Symbol *s = find_symbol($1->var, local_table);
                if (s == NULL) {
                    printf("\n\n\t***Error: Variable '%s' not declared***\n\t***Line: %d***\n\n\n", $1->var, yylineno);
                    n_error++;
                } else if (s->data_type != $1->val_type) {
                    printf("\n\n\t***Error: Variable '%s' has been declared as a '%s' but type '%s' is assigned***\n\t***Line: %d***\n\n\n", 
                        $1->var, type_to_str(s->data_type), type_to_str($1->val_type), yylineno);
                    n_error++;
                } else {
                    $$->value.assign = $1;
                    s->value_sym = $1->a_val;
                    debug_print("Assignment statement created", $$);
                }
            }
        |   initialization SEMICOLON 
            {
                debug_print("Creating statement from initialization", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = INIT_NODE;
                $$->value.init = $1;
                struct Symbol *s = NULL;
                for(struct AST_Node_Init *init = $1; init != NULL; init = init->next_init) {
                    s = find_symbol(init->assign->var, local_table);
                    if (s == NULL) {
                        s = add_symbol(init->assign->var, local_table, SYMBOL_VARIABLE, $1->data_type, DATA_TYPE_NONE, false, NULL, false, yylineno, null_value);
                        debug_print("Variable symbol added", s);
                    } else {
                        printf("\n\n\t***Error: Variable %s already declared***\n\t***Line: %d***\n\n\n", init->assign->var, yylineno);
                        n_error++;
                    }
                }
                debug_print("Initialization statement created", $$);
            }
        |   output_stmnt SEMICOLON {
            debug_print("Creating statement from output", NULL);
            $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
            $$->n_type = OUTPUT_NODE;
            $$->value.outputNode = $1;
            debug_print("Output statement created", $$);
        }
        |   create_class
            { 
                debug_print("Creating statement from class definition", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = CLASS_NODE;
                $$->value.classNode = $1;
                debug_print("Class statement created", $$);
            }
        |   create_class_child
            { 
                debug_print("Creating statement from class inheritance definition", NULL);
                $$ = (struct AST_Node_Instruction*)malloc(sizeof(struct AST_Node_Instruction));
                $$->n_type = CLASS_CHILD_NODE;
                $$->value.classNode = $1;
                debug_print("Class inheritance statement created", $$);
            }
        ;

    
    function_call:
                ID LPAR multi_fun_param RPAR    { 
                                                $$ = (struct AST_Node_FunctionCall*)malloc(sizeof(struct AST_Node_FunctionCall));
                                                struct Symbol *s = find_symtab($1, local_table);
                                                if (s!=NULL) 
                                                    {
                                                    if (s->is_function) {
                                                        $$->func_name = $1;
                                                        $$->return_type = s->ret_type;
                                                        $$->params = $3;
                                                        /* Check if the function exists and if parameters are legit */
                                                        check_function_call($$);                                                    
                                                        }
                                                    else {
                                                        printf("\n\n\t***Error: %s is not a function***\n\t***Line: %d***\n\n\n",$1,yylineno);n_error++;
                                                        }
                                                    }
                                                else { printf("\n\n\t***Error: %s is not declared***\n\t***Line: %d***\n\n\n",$1,yylineno); n_error++;}
                                                }
            |   ID LPAR RPAR                   { 
                                                $$ = (struct AST_Node_FunctionCall*)malloc(sizeof(struct AST_Node_FunctionCall));
                                                struct Symbol *s = find_symtab($1, local_table);
                                                if (s!=NULL) 
                                                    {
                                                    if (s->is_function) {
                                                        $$->func_name = $1;
                                                        $$->return_type = s->ret_type;
                                                        $$->params = NULL;
                                                        /* Check if the function exists and if parameters are legit */
                                                        check_function_call($$);                                                    
                                                        }
                                                    else {
                                                        printf("\n\n\t***Error: %s is not a function***\n\t***Line: %d***\n\n\n",$1,yylineno);n_error++;
                                                        }
                                                    }
                                                else { printf("\n\n\t***Error: %s is not declared***\n\t***Line: %d***\n\n\n",$1,yylineno); n_error++;}
                                                };


    function_def:
                types ID LPAR multi_fun_param RPAR LBRACE func_body RBRACE 
                                        { scope_enter();
                    $$ = (struct AST_Node_FunctionDef*)malloc(sizeof(struct AST_Node_FunctionDef));
                    $$->func_name = $2;
                    $$->params = $4;
                    $$->f_body = $7;
                    $$->return_type = $1;
                    $$->is_class_method = is_inside_class;  // Flag if this is a class method
                    
                    // Check return type only if a return value exists
                    if ($$->f_body && $$->f_body->return_op) {
                        if ($1 != $$->f_body->return_op->val_type) {
                            printf("\n\n\t***Error: Function %s has been declared as a '%s' but type '%s' is returned ***\n\n\n", 
                                $$->func_name, type_to_str($1), type_to_str($$->f_body->return_op->val_type));
                            n_error++;
                        }
                    }
                    
                    // add function to function array
                    function_array[function_counter] = $$;
                    function_counter++;
                    
                    scope_exit();
                    printf("[DEBUG] Defined function %s with return type %s\n", $$->func_name, type_to_str($$->return_type));
                                        }
            | types ID LPAR RPAR LBRACE func_body RBRACE 
                                        { scope_enter();
                                        $$ = (struct AST_Node_FunctionDef*)malloc(sizeof(struct AST_Node_FunctionDef));
                                        $$->func_name = $2;
                                        $$->params = NULL;
                                        $$->f_body = $6;
                                        $$->return_type = $1;
                                        $$->is_class_method = is_inside_class;  // Flag if this is a class method
                                        
                                        // Check return type only if a return value exists
                                        if ($$->f_body && $$->f_body->return_op) {
                                            if ($1 != $$->f_body->return_op->val_type) {
                                                printf("\n\n\t***Error: Function %s has been declared as a '%s' but type '%s' is returned ***\n\n\n", 
                                                    $$->func_name, type_to_str($1), type_to_str($$->f_body->return_op->val_type));
                                                n_error++;
                                            }
                                        }
                                        
                                        // add function to function array
                                        function_array[function_counter] = $$;
                                        function_counter++;
                                        
                                        scope_exit();
                                        printf("[DEBUG] Defined function %s with return type %s\n", $$->func_name, type_to_str($$->return_type));
                                        }
            | INT MAIN LPAR RPAR func_body            {     
                                                        printf("[DEBUG] Matched main function\n");
                                                        scope_enter();
                                                        $$ = (struct AST_Node_FunctionDef*)malloc(sizeof(struct AST_Node_FunctionDef));
                                                        $$->func_name = "main";
                                                        $$->params = NULL;
                                                        $$->return_type = DATA_TYPE_INT;
                                                        $$->f_body = $5;
                                                        scope_exit();
                                                        }
            | initialization LPAR RPAR func_body      { if (in_class == false ){scope_enter();};
                                                        $$ = (struct AST_Node_FunctionDef*)malloc(sizeof(struct AST_Node_FunctionDef));
                                                        $$->func_name = $1->assign->var;
                                                        $$->params = NULL;
                                                        $$->f_body = $4;
                                                        // check if return data type and function data type match
                                                        if ($1->data_type !=  $$->f_body->return_op->val_type)
                                                            {
                                                            printf("\n\n\t***Error: Function %s has been declared as a '%s' but type '%s' is returned ***\n\n\n", 
                                                            $$->func_name, type_to_str($1->data_type), type_to_str($$->f_body->return_op->val_type));n_error++;
                                                            }
                                                        $$->return_type = $1->data_type;
                                                        // add function to function array; 
                                                        function_array[function_counter] = $$;
                                                        function_counter++;
                                                        if (in_class == false ){scope_exit();};
                                                    }



    create_object:
                ID ID       { /*check if $1 exists */
                            struct Symbol *s = find_symtab($1, local_table);
                            if (s!=NULL) 
                                {
                                if (s->is_class) 
                                    {
                                    struct Symbol *s2 = find_symtab($2, local_table);
                                    if (s2==NULL) 
                                        {
                                        $$ = (struct AST_Node_Object*)malloc(sizeof(struct AST_Node_Object));
                                        $$->obj_class = (struct AST_Node_Class*)malloc(sizeof(struct AST_Node_Class));
                                        //Search class in the class array by name
                                        for (int i = 0; i<class_counter; i++){
                                            if (strcmp(class_array[i]->class_name, $1) ==0)
                                                { 
                                                $$->obj_class = class_array[i];
                                                $$->obj_name = $2;
                                                object_array[object_counter] = $$;
                                                object_counter++;
                                                break;
                                                }
                                            }
                                        }
                                    else { printf("\n\n\t***Error: object %s already exists***\n\t***Line: %d***\n\n\n",$2,yylineno); n_error++;}
                                    }
                                else { printf("\n\n\t***Error: %s is not a class***\n\t***Line: %d***\n\n\n",$1,yylineno); n_error++;}
                                }
                            else { printf("\n\n\t***Error: class %s is not declared***\n\t***Line: %d***\n\n\n",$1,yylineno); n_error++;}
                            };
                                      

 access_class:
                ID DOT ID               {
                                        // Search for the object in the object array by name
                                        for (int i = 0; i<object_counter; i++)
                                            {
                                            if (strcmp(object_array[i]->obj_name, $1) == 0)
                                                { 
                                                $$->obj_class = object_array[i]->obj_class;
                                                $$->obj_name = object_array[i]->obj_name;
                                                break;
                                                }
                                            }
                                        //Search class in class array by name
                                        for (int j = 0; j<class_counter; j++){
                                            if (strcmp(class_array[j]->class_name, $$->obj_class->class_name) ==0)
                                                {
                                                $$->obj_class->c_body->pub_body = class_array[j]->c_body->pub_body;
                                                break;
                                                }
                                            }
                                        //Search attribute in the same class of the object
                                        if (search_class_body($3, $$->obj_class->c_body->pub_body) == true)
                                            { $$->access_value.val = $3; }
                                        else 
                                            {
                                        // check if the attribute is present in the parent classes 
                                            for (int k = 0; k<class_counter; k++)
                                                {
                                                // check if the class is present in the classes array
                                                if (strcmp(class_array[k]->class_name, $$->obj_class->class_name) == 0)
                                                    {
                                                    // check if the class has a parent
                                                    if (class_array[k]->parent_class_public != NULL)
                                                        {
                                                        $$->obj_class->parent_class_public = class_array[k]->parent_class_public;
                                                        // cycle in the public body of each parent classes 
                                                        for (   class_array[k]->parent_class_public->parent_pub_body;
                                                                class_array[k]->parent_class_public->parent_pub_body != NULL;
                                                                class_array[k]->parent_class_public->parent_pub_body = class_array[k]->parent_class_public->next_parent_public->parent_pub_body
                                                            ){
                                                            // check if the attribute is present in the public body of the parent class
                                                            if (search_class_body($3, class_array[k]->parent_class_public->parent_pub_body) == true)
                                                                {                                       
                                                                $$->access_value.val = $3;
                                                                $$->access_type = ACCESS_TYPE_VAR;
                                                                break;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if ($$->access_value.val == NULL){printf("\n\n\n\t\t***ERROR: %s not found in class %s***\n\n\n", $3,$$->obj_class->class_name);n_error++;}
                                        }
        |       ID DOT function_call    {                     
                                        // Search for the object in the object array by name
                                        for (int i = 0; i<object_counter; i++)
                                            {
                                            if (strcmp(object_array[i]->obj_name, $1) ==0)
                                                { 
                                                $$->obj_class = object_array[i]->obj_class;
                                                $$->obj_name = object_array[i]->obj_name;
                                                break;
                                                }
                                            }
                                        //Search class in class array by name
                                        for (int j = 0; j<class_counter; j++){
                                            if (strcmp(class_array[j]->class_name, $$->obj_class->class_name) ==0)
                                                {
                                                $$->obj_class->c_body->pub_body = class_array[j]->c_body->pub_body;
                                                break;
                                                }
                                            }
                                        //Search attribute in the same class of the object
                                        if (search_class_body($3->func_name, $$->obj_class->c_body->pub_body) == true)
                                            {
                                            $$->access_value.funca = $3;
                                            $$->access_type = ACCESS_TYPE_FUNCTION;
                                            }
                                        else 
                                            {
                                        // check if the attribute is present in the parent classes 
                                            for (int k = 0; k<class_counter; k++){
                                                // check if the class is present in the classes array
                                                if (strcmp(class_array[k]->class_name, $$->obj_class->class_name) == 0)
                                                    {
                                                    // check if the class has a parent
                                                    if (class_array[k]->parent_class_public != NULL)
                                                        {
                                                        $$->obj_class->parent_class_public = class_array[k]->parent_class_public;
                                                        // cycle in the public body of each parent classes   
                                                        for (   class_array[k]->parent_class_public->parent_pub_body;
                                                                class_array[k]->parent_class_public->parent_pub_body != NULL;
                                                                class_array[k]->parent_class_public->parent_pub_body = class_array[k]->parent_class_public->next_parent_public->parent_pub_body
                                                            ){
                                                            // check if the attribute is present in the public body of the parent class
                                                            if (search_class_body($3->func_name, class_array[k]->parent_class_public->parent_pub_body) == true){
                                                                $$->access_value.funca = $3;
                                                                $$->access_type = ACCESS_TYPE_FUNCTION;
                                                                break;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if ($$->access_value.funca == NULL){printf("\n\n\t***Error: %s not found in class %s***\n\t***Line: %d***\n\n\n",$3->func_name,$$->obj_class->class_name,yylineno);n_error++;}
                                        }
        |       ID DOT assignment       { 
                                        // Search for the object in the object array by name
                                        for (int i = 0; i<object_counter; i++)
                                            {
                                            if (strcmp(object_array[i]->obj_name, $1) == 0)
                                                { 
                                                $$->obj_class = object_array[i]->obj_class;
                                                $$->obj_name = object_array[i]->obj_name;
                                                break;
                                                }
                                            }
                                        //Search class in class array by name

                                        for (int j = 0; j<class_counter; j++)
                                            {
                                            if (strcmp(class_array[j]->class_name, $$->obj_class->class_name) == 0)
                                                {
                                                $$->obj_class->c_body->pub_body = class_array[j]->c_body->pub_body;
                                                break;
                                                }
                                            }

                                            //Search attribute in the same class of the object
                                        if (search_class_body($3->var, $$->obj_class->c_body->pub_body) == true)
                                            {
                                            $$->access_value.ass_val = $3;
                                            $$->access_type = ACCESS_TYPE_ASSIGN;
                                            }
                                        else 
                                            {
                                            // check if the attribute is present in the parent classes 
                                            for (int k = 0; k<class_counter; k++)
                                                {
                                                // check if the class is present in the classes array
                                                if (strcmp(class_array[k]->class_name, $$->obj_class->class_name) == 0)
                                                    {
                                                    // check if the class has a parent
                                                    if (class_array[k]->parent_class_public != NULL)
                                                        {
                                                        $$->obj_class->parent_class_public = class_array[k]->parent_class_public;
                                                        // cycle in the public body of each parent classes   
                                                        for (   class_array[k]->parent_class_public->parent_pub_body;
                                                                class_array[k]->parent_class_public->parent_pub_body != NULL;
                                                                class_array[k]->parent_class_public->parent_pub_body = class_array[k]->parent_class_public->next_parent_public->parent_pub_body
                                                            ){

                                                            // check if the attribute is present in the public body of the parent class
                                                            if (search_class_body($3->var, class_array[k]->parent_class_public->parent_pub_body) == true)
                                                                { 
                                                                $$->access_value.ass_val = $3;
                                                                $$->access_type = ACCESS_TYPE_ASSIGN;
                                                                break;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }                                                                    
                                            }
                                            if ($$->access_value.ass_val == NULL){printf("\n\n\t***Error: %s not found in class %s***\n\t***Line: %d***\n\n\n",$3->var,$$->obj_class->class_name,yylineno);n_error++;}
                                        };


    create_class:
                CLASS ID                {in_class = true;}
                class_body              {
                                        $$ = (struct AST_Node_Class*)malloc(sizeof(struct AST_Node_Class));
                                        $$->parent_class_public = (struct AST_Node_Parent_Public*)malloc(sizeof(struct AST_Node_Parent_Public));
                                        $$->class_name = $2;
                                        $$->c_body = $4;
                                        $$->parent_class_public = NULL;
                                        class_array[class_counter] = $$;
                                        class_counter++;
                                        in_class = false;
                                        };


    create_class_child:
                CLASS ID                       {in_class = true;}
                COLON PUBLIC ID class_body     {
                                                        $$ = (struct AST_Node_Class*)malloc(sizeof(struct AST_Node_Class));
                                                        $$->parent_class_public = (struct AST_Node_Parent_Public*)malloc(sizeof(struct AST_Node_Parent_Public));
                                                        $$->class_name = $2;
                                                        $$->c_body = $7;
                                                        // search parent class in the class array
                                                        for (int i = 0; i<class_counter; i++)
                                                            {
                                                            // compare the name of the parent class in the statement with the name of the class in the class array
                                                             if (strcmp(class_array[i]->class_name, $6) == 0)
                                                                {
                                                                $$->parent_class = class_array[i];
                                                                $$->parent_class->class_name = class_array[i]->class_name;
                                                                $$->parent_class_public->parent_pub_body = class_array[i]->c_body->pub_body;
                                                                $$->parent_class_public->next_parent_public = class_array[i]->parent_class_public;
                                                                class_array[class_counter] = $$;        
                                                                class_counter++;
                                                                break;
                                                                }
                                                             else if (i == class_counter){printf("\n\n\n\t\t***ERROR: class parent %s not found***\n\n\n",$6); n_error++;}
                                                        }
                                                        in_class = false;

                                                        };


    class_body:
                LBRACE { is_inside_class = true; } sections RBRACE 
                    {
                    $$ = (struct AST_Node_CBody*)malloc(sizeof(struct AST_Node_CBody));
                    $$->pri_body = NULL;
                    $$->pub_body = NULL;
                    is_inside_class = false;
                    debug_print("Class body created", $$);
                    };


    sections:
                section
            |   sections section
            ;

    section:
                PUBLIC COLON statements 
                    { 
                    $$ = $3; 
                    debug_print("Public section processed", $$); 
                    }
            |   PRIVATE COLON statements 
                    { 
                    $$ = $3; 
                    debug_print("Private section processed", $$); 
                    }
            ;


    if_statement:
                IF LPAR if_condition RPAR body else_if_statement else_statement
                                                        { 
                                                        $$ = (struct AST_Node_If*)malloc(sizeof(struct AST_Node_If));
                                                        $$->condition = $3;
                                                        $$->if_body = $5;
                                                        $$->else_if = $6;
                                                        $$->else_body = $7;
                                                        }
                | IF LPAR if_condition RPAR body ELSE body
                                                        { 
                                                        $$ = (struct AST_Node_If*)malloc(sizeof(struct AST_Node_If));
                                                        $$->condition = $3;
                                                        $$->if_body = $5;
                                                        $$->else_if = NULL;
                                                        struct AST_Node_Else *else_node = (struct AST_Node_Else*)malloc(sizeof(struct AST_Node_Else));
                                                        else_node->else_body = $7;
                                                        $$->else_body = else_node;
                                                        }
                | IF LPAR if_condition RPAR body
                                                        { 
                                                        $$ = (struct AST_Node_If*)malloc(sizeof(struct AST_Node_If));
                                                        $$->condition = $3;
                                                        $$->if_body = $5;
                                                        $$->else_if = NULL;
                                                        $$->else_body = NULL;
                                                        };


    if_condition:
                expr                            {
                                                if($1->expr_type != DATA_TYPE_BOOL) { printf("\n\n\t***Error: IF condition must be boolean type***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                                else { $$ = $1; }
                                                };
    

    else_if_statement:
                ELSE IF LPAR if_condition RPAR body {
                                                    $$ = (struct AST_Node_Else_If*)malloc(sizeof(struct AST_Node_Else_If));
                                                    $$->condition = $4;
                                                    $$->elif_body = $6;
                                                    }
                | /* empty */ { $$ = NULL; };
    
    
    else_statement:
                ELSE body                       {
                                                $$ = (struct AST_Node_Else*)malloc(sizeof(struct AST_Node_Else));
                                                $$->else_body = $2;
                                                }
                | /* empty */ { $$ = NULL; };


    for_loop:
                FOR LPAR assignment SEMICOLON rel_expr SEMICOLON assignment RPAR body   {
                                                                                        $$ = (struct AST_Node_For*)malloc(sizeof(struct AST_Node_For));
                                                                                        $$->init = $3;
                                                                                        $$->condition = $5;
                                                                                        $$->increment = $7;
                                                                                        // The increment can be expressed only as x = x + 1 and not as x++ or x += 1
                                                                                        // The sign of the increment expression will be used at translation time for further control:
                                                                                        // The control is needed to solve a problem where the decrement is written as x = x -1 and not as x = x - 1
                                                                                        $$->increment->a_val.expr->op = $7->a_val.expr->op;
                                                                                        $$->for_body = $9;
                                                                                        delete_symbol( find_symbol($3->var,local_table), local_table);
                                                                                        };


    body: 
                LBRACE statements RBRACE          { $$ = $2; };

    
    func_body:
          LBRACE statements RETURN content SEMICOLON RBRACE
            {
                printf("[DEBUG] Function body with statements and return\n");
                $$ = (struct AST_Node_FBody*)malloc(sizeof(struct AST_Node_FBody));                                       
                $$->func_body = $2;
                $$->return_op = $4;
                printf("[DEBUG] Return type: %d\n", $$->return_op->val_type);
            }
        | LBRACE statements RETURN expr SEMICOLON RBRACE
            {
                printf("[DEBUG] Function body with statements and return expression\n");
                $$ = (struct AST_Node_FBody*)malloc(sizeof(struct AST_Node_FBody));                                       
                $$->func_body = $2;
                
                // Create an operand for the expression
                struct AST_Node_Operand *expr_operand = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                expr_operand->value.expr = $4;
                expr_operand->val_type = $4->expr_type;
                expr_operand->operand_type = CONTENT_TYPE_EXPRESSION;
                
                $$->return_op = expr_operand;
                printf("[DEBUG] Return expression type: %d\n", $$->return_op->val_type);
            }
        | LBRACE RETURN content SEMICOLON RBRACE
            {
                printf("[DEBUG] Function body with return only\n");
                $$ = (struct AST_Node_FBody*)malloc(sizeof(struct AST_Node_FBody));
                $$->func_body = NULL;
                $$->return_op = $3;
                printf("[DEBUG] Return type: %d\n", $$->return_op->val_type);
            }
        | LBRACE RETURN expr SEMICOLON RBRACE
            {
                printf("[DEBUG] Function body with return expression only\n");
                $$ = (struct AST_Node_FBody*)malloc(sizeof(struct AST_Node_FBody));
                $$->func_body = NULL;
                
                // Create an operand for the expression
                struct AST_Node_Operand *expr_operand = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                expr_operand->value.expr = $3;
                expr_operand->val_type = $3->expr_type;
                expr_operand->operand_type = CONTENT_TYPE_EXPRESSION;
                
                $$->return_op = expr_operand;
                printf("[DEBUG] Return expression type: %d\n", $$->return_op->val_type);
            }
        | LBRACE statements RBRACE
            {
                printf("[DEBUG] Function body with statements only (no return)\n");
                $$ = (struct AST_Node_FBody*)malloc(sizeof(struct AST_Node_FBody));
                $$->func_body = $2;
                // For a function with no return, set a default return type
                struct AST_Node_Operand *default_return = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                default_return->operand_type = CONTENT_TYPE_INT_NUMBER;
                default_return->val_type = DATA_TYPE_INT;
                default_return->value.val = strdup("0"); // Default return 0
                $$->return_op = default_return;
            }
    ;


    expr:
                math_expr
                {
                    $$ = $1;
                }
            |   ID INC
                {
                    debug_print("Creating increment expression", NULL);
                    struct AST_Node_Expression *node = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                    node->op = "+=";
                    
                    // Create left operand (variable)
                    struct AST_Node_Operand *left = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                    left->operand_type = CONTENT_TYPE_ID;
                    left->value.val = $1;
                    left->val_type = DATA_TYPE_INT;
                    node->left_op = left;
                    
                    // Create right operand (constant 1)
                    struct AST_Node_Operand *right = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                    right->operand_type = CONTENT_TYPE_INT_NUMBER;
                    right->value.val = "1";
                    right->val_type = DATA_TYPE_INT;
                    node->right_op = right;
                    
                    node->expr_type = DATA_TYPE_INT;
                    $$ = node;
                }
            |   ID DEC
                {
                    debug_print("Creating decrement expression", NULL);
                    struct AST_Node_Expression *node = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                    node->op = "-=";
                    
                    // Create left operand (variable)
                    struct AST_Node_Operand *left = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                    left->operand_type = CONTENT_TYPE_ID;
                    left->value.val = $1;
                    left->val_type = DATA_TYPE_INT;
                    node->left_op = left;
                    
                    // Create right operand (constant 1)
                    struct AST_Node_Operand *right = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                    right->operand_type = CONTENT_TYPE_INT_NUMBER;
                    right->value.val = "1";
                    right->val_type = DATA_TYPE_INT;
                    node->right_op = right;
                    
                    node->expr_type = DATA_TYPE_INT;
                    $$ = node;
                }
            |   logic_expr              { $$ = $1; }
            |   rel_expr                { $$ = $1; }
            |                           { $$ = NULL; }
            |   LPAR expr RPAR          { $$ = $2; };


    math_expr:
                content ADD content         {
                                            $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                            // queste malloc permettono il riconoscimento della x
                                            $$->left_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                            $$->right_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->op = $2;
                                            $$->expr_type = $3->val_type;
                                            if ($1->val_type != $3->val_type) 
                                                { printf("\n\n\t***Error: Cannot add '%s' to '%s'***\n\t***Line: %d***\n\n\n",type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                                
                                            else 
                                                {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                                };
                                            }
            |   content SUB content         { 
                                            $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                            $$->op = $2;
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = $1->val_type;
                                            if ($1->val_type != $3->val_type) 
                                                { printf("\n\n\t***Error: Cannot subtract '%s' to '%s'***\n\t***Line: %d***\n\n\n",type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                            else 
                                                {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                                };
                                            }
            |   content MUL content         { 
                                            $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                            // queste malloc permettono il riconoscimento della x
                                            $$->left_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                            $$->right_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->op = $2;
                                            if ($1->val_type != $3->val_type) 
                                                { printf("\n\n\t***Error: Cannot multiply '%s' to '%s'***\n\t***Line: %d***\n\n\n",type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                            else 
                                                {
                                                $$->left_op = $1;
                                                $$->right_op = $3;
                                                $$->expr_type = $1->val_type;
                                                }
                                            }
            |   content INT_NUMBER          {   
                                            // This rule is used in case expression written as: int x = A -B and not as x = A - B
                                            // check if the second token is a negative integer number
                                            if (atoi($2)<0) 
                                                {                                               
                                                int temp= atoi($2);
                                                temp = -temp;
                                                int length = snprintf( NULL, 0, "%d", temp );
                                                char* temp_str = (char*)malloc( length + 1 );
                                                //cast back to string
                                                snprintf( temp_str, length + 1, "%d", temp );

                                                // Need to allocate operands in order to use the expression
                                                struct AST_Node_Operand *S1, *S2;
                                                S1 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S1->value = $1->value;
                                                S1->val_type = DATA_TYPE_INT;
                                                S1->operand_type = CONTENT_TYPE_INT_NUMBER;

                                                S2 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S2->value.val = temp_str;
                                                S2->val_type = DATA_TYPE_INT;
                                                S2->operand_type = CONTENT_TYPE_INT_NUMBER;
                                                
                                                $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                                $$->op = "-";
                                                $$->left_op = S1;
                                                $$->right_op = S2;
                                                $$->expr_type = DATA_TYPE_INT;
                                            }
                                            else { printf("\n\n\t***Error: Operation not allowed ***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                            }
            |   INT_NUMBER INT_NUMBER       {   
                                            // This rule is used in case expression written as: int x = A -B and not as x = A - B
                                            // check if the second token is a negative integer number
                                            if (atoi($2)<0) 
                                                {                                               
                                                int temp= atoi($2);
                                                temp = -temp;
                                                int length = snprintf( NULL, 0, "%d", temp );
                                                char* temp_str = (char*)malloc( length + 1 );
                                                //cast back to string
                                                snprintf( temp_str, length + 1, "%d", temp );

                                                // Need to allocate operands in order to use the expression
                                                struct AST_Node_Operand *S1, *S2;
                                                S1 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S1->value.val = $1;
                                                S1->val_type = DATA_TYPE_INT;
                                                S1->operand_type = CONTENT_TYPE_INT_NUMBER;

                                                S2 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S2->value.val = temp_str;
                                                S2->val_type = DATA_TYPE_INT;
                                                S2->operand_type = CONTENT_TYPE_INT_NUMBER;
                                                
                                                $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                                $$->op = "-";
                                                $$->left_op = S1;
                                                $$->right_op = S2;
                                                $$->expr_type = DATA_TYPE_INT;
                                            }
                                            else { printf("\n\n\t***Error: Operation not allowed ***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                            }
                                            
            |   content FLOAT_NUMBER        {
                                            //check if the second token is a negative float number
                                            if (atof($2)<0) 
                                                {                                               
                                                float temp= atof($2);
                                                temp = -temp;
                                                int length = snprintf( NULL, 0, "%4.3f", temp );
                                                char* temp_str = (char*)malloc( length + 1 );
                                                //cast back to string
                                                snprintf( temp_str, length + 1, "%4.3f", temp );
                                                
                                                // Need to allocate operands in order to use the expression
                                                struct AST_Node_Operand *S1, *S2;
                                                S1 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S1->value = $1->value;
                                                S1->val_type = DATA_TYPE_FLOAT;
                                                S1->operand_type = CONTENT_TYPE_FLOAT_NUMBER;

                                                S2 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S2->value.val = temp_str;
                                                S2->val_type = DATA_TYPE_FLOAT;
                                                S2->operand_type = CONTENT_TYPE_FLOAT_NUMBER;
                                                
                                                $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                                $$->op = "-";
                                                $$->left_op = S1;
                                                $$->right_op = S2;
                                                $$->expr_type = DATA_TYPE_FLOAT;
                                            }
                                            else { printf("\n\n\t***Error: Operation not allowed***\n\t***Line: %d***\n\n\n",yylineno);n_error++; }
                                            }
            |   FLOAT_NUMBER FLOAT_NUMBER   {
                                            //check if the second token is a negative float number
                                            if (atof($2)<0) 
                                                {                                               
                                                float temp= atof($2);
                                                temp = -temp;
                                                int length = snprintf( NULL, 0, "%4.3f", temp );
                                                char* temp_str = (char*)malloc( length + 1 );
                                                //cast back to string
                                                snprintf( temp_str, length + 1, "%4.3f", temp );
                                                
                                                // Need to allocate operands in order to use the expression
                                                struct AST_Node_Operand *S1, *S2;
                                                S1 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S1->value.val = $1;
                                                S1->val_type = DATA_TYPE_FLOAT;
                                                S1->operand_type = CONTENT_TYPE_FLOAT_NUMBER;

                                                S2 = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                                S2->value.val = temp_str;
                                                S2->val_type = DATA_TYPE_FLOAT;
                                                S2->operand_type = CONTENT_TYPE_FLOAT_NUMBER;
                                                
                                                $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                                $$->op = "-";
                                                $$->left_op = S1;
                                                $$->right_op = S2;
                                                $$->expr_type = DATA_TYPE_FLOAT;

                                            }
                                            else { printf("\n\n\t***Error: Operation not allowed***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                            }
            |   content DIV content     { 
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        // queste malloc permettono il riconoscimento della x
                                        $$->left_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                        $$->right_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                        $$->left_op = $1;
                                        $$->right_op = $3;
                                        $$->op = $2;
                                        if ($1->val_type != $3->val_type) 
                                            { printf("\n\n\t***Error: Cannot divide '%s' by '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                        else    
                                            {
                                            if (strcmp($3->value.val,"0" ) == 0)   { printf("\n\n\t***Error: Cannot divide by 0***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                            else 
                                                {
                                                $$->left_op = $1;
                                                $$->right_op = $3;
                                                $$->expr_type = $1->val_type;
                                                }
                                            }
                                        };
    

    logic_expr:
                LPAR logic_expr RPAR    {   
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$ = $2;
                                        }
            |   content AND content     {   
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->op = $2;
                                        if ($1->val_type != DATA_TYPE_BOOL || $3->val_type != DATA_TYPE_BOOL) 
                                            { printf("\n\n\t***Error: Cannot AND '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno);n_error++; }
                                        else {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        }
            |   content OR content      {   
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->op = $2;
                                        if ($1->val_type != DATA_TYPE_BOOL || $3->val_type != DATA_TYPE_BOOL) 
                                            { printf("\n\n\t***Error: Cannot OR '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno);n_error++; }
                                        else 
                                            {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        };
    

    rel_expr:
                LPAR rel_expr RPAR      {  
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$ = $2; 
                                        }
            |   content LT content      { 
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->left_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                        $$->right_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                        $$->left_op = $1;
                                        $$->right_op = $3;
                                        $$->op = $2;
                                        if ($1->val_type != $3->val_type) 
                                            { printf("\n\n\t***Error: Cannot compare '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                        else if ($1->val_type == DATA_TYPE_BOOL) 
                                            { printf("\n\n\t***Error: Cannot compare boolean values***\n\t***Line: %d***\n\n\n",yylineno);n_error++; }
                                        else {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        }
            |   content LE content      { 
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->op = $2;
                                        if ($1->val_type != $3->val_type) 
                                            { printf("\n\n\t***Error: Cannot compare '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                        else if ($1->val_type == DATA_TYPE_BOOL) 
                                            { printf("\n\n\t***Error: Cannot compare boolean values***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                        else 
                                            {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        }
            |   content GT content      { 
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->op = $2;
                                        if ($1->val_type != $3->val_type) 
                                            { printf("\n\n\t***Error: Cannot compare '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                        else if ($1->val_type == DATA_TYPE_BOOL) 
                                            { printf("\n\n\t***Error: Cannot compare boolean values***\n\t***Line: %d***\n\n\n",yylineno); n_error++;}
                                        else 
                                            {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        }
            |   content GE content      {
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->op = $2;
                                        if ($1->val_type != $3->val_type) 
                                            { printf("\n\n\t***Error: Cannot compare '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno);n_error++; }
                                        else if ($1->val_type == DATA_TYPE_BOOL) 
                                            { printf("\n\n\t***Error: Cannot compare boolean values***\n\t***Line: %d***\n\n\n",yylineno);n_error++; }
                                        else 
                                            {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        }
            |   content EEQ content     { 
                                        $$ = (struct AST_Node_Expression*)malloc(sizeof(struct AST_Node_Expression));
                                        $$->op = $2;
                                        if ($1->val_type != $3->val_type) 
                                            { printf("\n\n\t***Error: Cannot compare '%s' with '%s'***\n\t***Line: %d***\n\n\n", type_to_str($1->val_type), type_to_str($3->val_type),yylineno); n_error++;}
                                        else 
                                            {
                                            $$->left_op = $1;
                                            $$->right_op = $3;
                                            $$->expr_type = DATA_TYPE_BOOL;
                                            }
                                        };


    input_stmnt:
                CIN multi_rshift  { $$=$2; };
        
    
    output_stmnt:
                COUT multi_lshift {
                    debug_print("Creating output statement", NULL);
                    $$ = $2;
                    debug_print("Output statement created", $$);
                }
                ;
    
    
    multi_rshift:
                single_rshift multi_rshift  {                     
                                            $1->next_input = $2;
                                            $$ = $1; 
                                            }
            |                               { $$=NULL; };
    
    
    multi_lshift:
                single_lshift { // Base case for the recursion
                    debug_print("multi_lshift: single_lshift base case", $1);
                    $$ = (struct AST_Node_Output*)malloc(sizeof(struct AST_Node_Output));
                    $$->output_op = $1; // $1 is an AST_Node_Operand from single_lshift
                    $$->next_output = NULL;
                }
            |   single_lshift multi_lshift { // Recursive step
                    debug_print("multi_lshift: single_lshift multi_lshift recursive step", $1);
                    $$ = (struct AST_Node_Output*)malloc(sizeof(struct AST_Node_Output));
                    $$->output_op = $1; // $1 is an AST_Node_Operand from single_lshift
                    $$->next_output = $2; // $2 is the AST_Node_Output from the recursive call
                }
                ;


    single_rshift:
                RSHIFT ID               {
                                        $$ = (struct AST_Node_Input*)malloc(sizeof(struct AST_Node_Input));
                                        $$->input_op = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                        struct Symbol *s = find_symbol($2, local_table);
                                        if(s == NULL) { $$->input_op->val_type = DATA_TYPE_NONE; }
                                        else    
                                            {
                                        $$->input_op->value.val = $2;
                                        $$->input_op->val_type = s->data_type;
                                        $$->input_op->operand_type = CONTENT_TYPE_ID;
                                            }
                                        };
    
    
    single_lshift:
                LSHIFT content  {
                    $$ = $2;
                }
                ;


    multi_fun_param:
                fun_param                          {
                                                    $1->next_param = NULL;
                                                    $$ = $1;
                                                    }
            |   fun_param COMMA  multi_fun_param    {
                                                    $1->next_param = $3;
                                                    $$ = $1;
                                                    };


    fun_param:
                types ID        { 
                                $$ = (struct AST_Node_Params*)malloc(sizeof(struct AST_Node_Params));
                                $$->decl_param = (struct AST_Node_Init*)malloc(sizeof(struct AST_Node_Init));
                                $$->decl_param->data_type = $1;
                                $$->decl_param->assign = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                                $$->decl_param->assign->val_type = $1;
                                $$->decl_param->assign->var = $2;
                                $$->decl_param->assign->a_val.val = NULL;
                                $$->decl_param->assign->a_type = CONTENT_TYPE_ID;
                                }
            |   content         { 
                                $$ = (struct AST_Node_Params*)malloc(sizeof(struct AST_Node_Params));
                                //$$->call_param = malloc(sizeof(struct AST_Node_Operand));
                                $$->call_param = $1;
                                //$$->call_param->val_type = $1->val_type;
                                };
                                        

    initialization:
                types ID        {
                                $$ = (struct AST_Node_Init*)malloc(sizeof(struct AST_Node_Init));
                                $$->data_type = $1;
                                $$->next_init = NULL;
                                $$->assign = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                                $$->assign->val_type = $1;
                                $$->assign->var = $2;
                                $$->assign->a_val.val = NULL;
                                $$->assign->a_type = CONTENT_TYPE_ID;
                                };


    assignment:
                ID EQ ID            { 
                                    $$ = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                                    $$->var = $1;
                                    $$->a_val.val = $3;
                                    $$->a_type = CONTENT_TYPE_ID;
                                    struct Symbol *s = find_symbol($3, local_table);
                                    if (s==NULL) { $$->val_type = DATA_TYPE_NONE; }
                                    else { $$-> val_type = s->data_type; }
                                    }
           |  types ID EQ content   { 
                                    struct Symbol *s = NULL;
                                    s = find_symbol($2, local_table);
                                    if (s == NULL)  
                                        { s = add_symbol($2, local_table, SYMBOL_VARIABLE, $1, $1, false, NULL, false, yylineno, $4->value); }
                                    else { printf("\n\n\t***Error: Variable %s already declared, value is %s***\n\t***Line: %d***\n\n\n",$2,s->value_sym.val,yylineno); n_error++;}
                                    if(($1 != $4->val_type))
                                        { printf("\n\n\t***Error: Cannot assign type %s to type %s***\n\t***Line: %d***\n\n\n",type_to_str($4->val_type),type_to_str($1),yylineno); n_error++;}
                                    else
                                        {
                                        $$ = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                                        $$->a_type = $4->operand_type;
                                        $$->var = $2;
                                        $$->a_val = $4->value;
                                        $$->val_type = $1;
                                        }
                                    }
           | ID EQ content          { 
                                    $$ = (struct AST_Node_Assign*)malloc(sizeof(struct AST_Node_Assign));
                                    $$->var = $1;
                                    $$->a_val = $3->value;
                                    $$->val_type = $3->val_type;
                                    $$->a_type = $3->operand_type;
                                    };


    content:
                ID              { 
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                struct Symbol *s = find_symtab($1, local_table);
                                if(s==NULL) { $$->val_type = DATA_TYPE_NONE; }
                                else 
                                    {
                                    $$->value.val = $1;
                                    $$->val_type = s->data_type;
                                    $$->operand_type = CONTENT_TYPE_ID;
                                    }
                                }
            |   FLOAT_NUMBER    {
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                $$->value.val = $1;
                                $$->val_type = DATA_TYPE_FLOAT;
                                $$->operand_type = CONTENT_TYPE_FLOAT_NUMBER;
                                }
            |   INT_NUMBER      {
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                $$->value.val = $1;
                                $$->val_type = DATA_TYPE_INT;
                                $$->operand_type = CONTENT_TYPE_INT_NUMBER;
                                }
            |   STRING_V        { 
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                $$->value.val = $1;
                                $$->val_type = DATA_TYPE_STRING;
                                $$->operand_type = CONTENT_TYPE_STRING;
                                }
            |   BOOL_V          { 
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                if (strcmp($1,"false")==0){$$->value.val = "False";}
                                else if (strcmp($1,"true")==0){$$->value.val = "True";}
                                $$->val_type = DATA_TYPE_BOOL;
                                $$->operand_type = CONTENT_TYPE_BOOL;
                                }
            |   function_call   {
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                $$->value.funca = $1;
                                $$->val_type = $1->return_type;
                                $$->operand_type = CONTENT_TYPE_FUNCTION;
                                }
            |   expr            { 
                                $$ = (struct AST_Node_Operand*)malloc(sizeof(struct AST_Node_Operand));
                                $$->value.expr = $1;
                                $$->val_type = $1->expr_type;
                                $$->operand_type = CONTENT_TYPE_EXPRESSION;
                                };


    types:
            FLOAT   { $$ = DATA_TYPE_FLOAT; }
        |   INT     { $$ = DATA_TYPE_INT; }
        |   STRING  { $$ = DATA_TYPE_STRING; }
        |   BOOL    { $$ = DATA_TYPE_BOOL; };
%%

/****************** Functions *****************/ 

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s input_file output_file\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        printf("Error: Cannot open input file %s\n", argv[1]);
        return 1;
    }

    fptr = fopen(argv[2], "w");
    if (fptr == NULL) {
        printf("Error: Cannot open output file %s\n", argv[2]);
        fclose(yyin);
        return 1;
    }

    yyparse();

    if (n_error == 0) {
        traverse(root);
    }

    // Clean up arrays before exiting
    cleanup_arrays();

    fclose(yyin);
    fclose(fptr);
    return 0;
}

int yyerror(char *s) {
    fprintf(stderr, "Error: %s\n", s);
    return 0;
}

/****************** Scope handling *****************/ 

void scope_enter(){
    local_table = new_symtab(indent_counter, local_table);
    indent_counter++;
}

void scope_exit(){
    delete_symtab(local_table);
    indent_counter--;
}

/****************** Convert Data Type to String and viceversa *****************/ 

char * type_to_str(int type) {
    switch (type) {
        case DATA_TYPE_STRING:
            return strdup("string");
        case DATA_TYPE_FLOAT:
            return strdup("float");
        case DATA_TYPE_INT:
            return strdup("int");
        case DATA_TYPE_BOOL:
            return strdup("bool");
        case DATA_TYPE_NONE:
            return strdup("Type none");
        default:
            return strdup("Type not defined");
    }
}

// Debug print function
void debug_print(const char *msg, void *ptr) {
    printf("[DEBUG] %s: %p\n", msg, ptr);
}

void debug_token(const char *token_name, const char *token_value) {
    printf("[TOKEN] %s: '%s'\n", token_name, token_value);
}
