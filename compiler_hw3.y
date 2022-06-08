/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fp, "\t"); \
            } \
            fprintf(fp, __VA_ARGS__); \
        } while (0)

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
   
    typedef struct symtable_node symtable_type;
    struct symtable_node{
        int level;
        int index;
        char* name;
        char* type;
        int address;
        int lineno;
        char* func_sig;
        symtable_type* next;
    };

    typedef struct symtable_stack_node symtable_stack_type;
    struct symtable_stack_node{
        symtable_type* table;
        int level;
        symtable_stack_type* next;
    };

    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* Func_sig, int para_type);
    static symtable_type* lookup_symbol(char * name);
    static void dump_symbol();
    static char* find_para(char* name);


    /* Global variables */
    int label_number = 0;

    symtable_stack_type* stack_head = NULL;

    bool g_has_error = false;
    FILE *fp = NULL;
    int g_indent_cnt = 0;
    int global_level = -1;
    int global_address = 0;

    int case_num = 0;
    int switch_num = 0;
    int continue_num = 0;

    char *str_funct_name;
    char *funct_parameter;
    char *funct_parameterUp;
    char *funct_parameterIn;
    char *funct_parameterDown;
    char *funct_parameterReturn;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    struct{
        union{
                int i_val;
                float f_val;
                char *s_val;
                bool b_val;
        }value;
        char * type;
    }item;
}

/* Token without return */
%token VAR NEWLINE
%token INT FLOAT BOOL STRING
%token INC DEC GEQ LOR LAND EQ LEQ NEQ
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN
%token IF ELSE FOR SWITCH CASE FUNC
%token PRINT PACKAGE RETURN PRINTLN
/*%token Type*/

%token DEFAULT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <s_val> STRING_LIT
%token <b_val> BOOL_LIT
%token <f_val> FLOAT_LIT
%token <s_val> IDENT


/* Nonterminal with return, which need to sepcify type */
%type <s_val> ReturnType Type INT FLOAT BOOL STRING

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
        : GlobalStatementList   {dump_symbol();}
;

GlobalStatementList 
        : GlobalStatementList GlobalStatement
        | GlobalStatement
;

GlobalStatement
        : PackageStmt NEWLINE 
        | FunctionDeclStmt
        | NEWLINE
;

PackageStmt
        : PACKAGE IDENT         {create_symbol(); printf("package: %s\n", $<item.value.s_val>2);}
;

FunctionDeclStmt
        : FuncOpen FuncParameter ReturnType FuncBlock
;

FuncParameter
        : '(' ParameterList ')'  {    
                                        funct_parameterUp = (char*)malloc(sizeof(char)*1);
                                        funct_parameterUp[0] = '(';
                                        funct_parameterIn = (char*)malloc(sizeof($<item.value.s_val>2) + 1);
                                        strcpy(funct_parameterIn, $<item.value.s_val>2);
                                        funct_parameterDown = (char*)malloc(sizeof(char)*1);
                                        funct_parameterDown[0] = ')';
                                 }   
;

FuncOpen
        : FUNC IDENT {
                        printf("func: %s\n", $<item.value.s_val>2);
                        create_symbol();
                        str_funct_name = (char *)malloc( strlen($<item.value.s_val>2) + 1); 
                        strcpy(str_funct_name, $<item.value.s_val>2);
                     }   
;

FuncBlock
	: FunctionUpBlock StatementList ReturnStmt '}' { dump_symbol(); fprintf(fp, ".end method\n"); }
;

FunctionUpBlock
        : '{'
;

UnaryExpr
        : PrimaryExpr {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | UnaryExpr INC {
                                // printf("INC\n");$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;
                                $<item>$ = $<item>1;
                                if (strcmp("float32", $<item.type>1) == 0){
                                        // $<item.value.f_val>$++; don't need it
                                        if ($<item.value.s_val>1 != NULL){
                                                // lookup_symbol($<token.value.s_val>1) -> value.f_val++; // don't need it
                                                fprintf(fp, "ldc 1.0\n");
                                                fprintf(fp, "fadd\n");
                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) ->  address);
                                        }
                                }else if (strcmp("int32", $<item.type>1) == 0){
                                        // $<token.value.i_val>$++;
                                        if ($<item.value.s_val>1 != NULL){
                                                // lookup_symbol($<token.name>1) -> value.i_val++;
                                                fprintf(fp, "ldc 1\n");
                                                fprintf(fp, "iadd\n");
                                                fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) ->  address);
                                        }
                                }
                        }
        | UnaryExpr DEC {
                                // printf("DEC\n");$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;
                                $<item>$ = $<item>1;
                                if (strcmp("float32", $<item.type>1) == 0){
                                        // $<item.value.f_val>$--; don't need it
                                        if ($<item.value.s_val>1 != NULL){
                                                // lookup_symbol($<token.value.s_val>1) -> value.f_val--; // don't need it
                                                fprintf(fp, "ldc 1.0\n");
                                                fprintf(fp, "fsub\n");
                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) ->  address);
                                        }
                                }else if (strcmp("int32", $<item.type>1) == 0){
                                        // $<token.value.i_val>$--;
                                        if ($<item.value.s_val>1 != NULL){
                                                // lookup_symbol($<token.name>1) -> value.i_val--;
                                                fprintf(fp, "ldc 1\n");
                                                fprintf(fp, "isub\n");
                                                fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) ->  address);
                                        }
                                }
                        }
        | unary_op cast_expression {
					printf("%s\n", $<item.value.s_val>1);
					$<item.type>$=$<item.type>2;
                                        $<item.value>$=$<item.value>2;

					if (strcmp($<item.value.s_val>1, "NEG") == 0){
						if(strcmp($<item.type>2, "int32")==0){
							fprintf(fp,"ineg\n");
						}
						else if(strcmp($<item.type>2, "float32") == 0){
							fprintf(fp, "fneg\n");
						}
					} 
					else if (strcmp($<item.value.s_val>1, "NOT") == 0){
						$<item.type>$ = "bool";
						// $<item.value>$= ! $<item.value>2;
						fprintf(fp, "ixor\n");
					}
				//printf("end unary cast\n");	
				}
;

cast_expression
        : UnaryExpr {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | '(' Type ')' cast_expression {$<item.type>$=$<item.type>2; $<item.value>$=$<item.value>2;}

multiplicative_expression
        : cast_expression                               { $<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | multiplicative_expression mul_op cast_expression {    if( !strcmp($<item.value.s_val>2,"REM") && strcmp($<item.type>1,"int32")){
                                                                        printf("error:%d: invalid operation: (operator REM not defined on %s)\n",yylineno,$<item.type>1);
                                                                }
                                                                else if( !strcmp($<item.value.s_val>2,"REM") && strcmp($<item.type>3,"int32")){
                                                                        printf("error:%d: invalid operation: (operator REM not defined on %s)\n",yylineno,$<item.type>3);
                                                                }

                                                                else if( strcmp($<item.type>1,$<item.type>3)!=0 ){
                                                                        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n"
                                                                        ,yylineno ,$<item.value.s_val>2, $<item.type>1,$<item.type>3);
                                                                }

                                                                $<item.type>$=$<item.type>1;
								if((strcmp($<item.value.s_val>2,"MUL")==0)){
									if(strcmp($<item.type>1,"int32")==0) { fprintf(fp, "imul\n"); }
									else if (strcmp($<item.type>1,"float32")==0) { fprintf(fp, "fmul\n"); }
								}
                                                 		else if((strcmp($<item.value.s_val>2,"QUO")==0)){
                                                                         if(strcmp($<item.type>1,"int32")==0) { fprintf(fp, "idiv\n"); }
                                                                         else if (strcmp($<item.type>1,"float32")==0) { fprintf(fp, "fdiv\n"); }
	                                                        }
								else if((strcmp($<item.value.s_val>2,"REM")==0)){
                                                                         if(strcmp($<item.type>1,"int32")==0) { fprintf(fp, "irem\n"); }
                                                                } 
                                                                printf("%s\n", $<item.value.s_val>2);
							}
								
;

additive_expression
        : multiplicative_expression                             {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | additive_expression add_op multiplicative_expression {
								if( strcmp($<item.type>1,$<item.type>3)!=0 ){
                                                                        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n"
                                                                        ,yylineno ,$<item.value.s_val>2, $<item.type>1,$<item.type>3);
                                                                }

                                                                $<item.type>$=$<item.type>3;
                                                                if((strcmp($<item.value.s_val>2,"ADD")==0)){
                                                                        if(strcmp($<item.type>1,"int32")==0) { fprintf(fp, "iadd\n"); }
                                                                        else if (strcmp($<item.type>1,"float32")==0) { fprintf(fp, "fadd\n"); }
                                                                }
                                                                else if((strcmp($<item.value.s_val>2,"SUB")==0)){
                                                                         if(strcmp($<item.type>1,"int32")==0) { fprintf(fp, "isub\n"); }
                                                                         else if (strcmp($<item.type>1,"float32")==0) { fprintf(fp, "fsub\n"); }
                                                                }
								printf("%s\n", $<item.value.s_val>2);
								}
;

relational_expression
        : additive_expression                                   {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | relational_expression rel_op additive_expression {    if( strcmp($<item.type>1,$<item.type>3)!=0 ){
                                                                        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n"
                                                                        ,yylineno ,$<item.value.s_val>2, $<item.type>1,$<item.type>3);
                                                                }
                                                                $<item.type>$="bool";
                                                                printf("%s\n", $<item.value.s_val>2);
                                                                
                                                                if(strcmp($<item.value.s_val>2, "LTR")==0){
                                                                        if (strcmp($<item.type>1, "float32") == 0 && strcmp($<item.type>3, "float32") == 0) {
                                                                                fprintf(fp, "fcmpl\niflt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++; 
                                                                                label_number++;
                                                                        }else if (strcmp($<item.type>1, "int32") == 0 && strcmp($<item.type>3, "int32") == 0) {
                                                                                fprintf(fp, "isub\niflt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "LEQ")==0){
                                                                        if (strcmp($<item.type>1, "float32") == 0 && strcmp($<item.type>3, "float32") == 0) {
                                                                                fprintf(fp, "fcmpl\nifle L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }else if (strcmp($<item.type>1, "int32") == 0 && strcmp($<item.type>3, "int32") == 0) {
                                                                                fprintf(fp, "isub\nifle L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "GTR")==0){
                                                                        if (strcmp($<item.type>1, "float32") == 0 && strcmp($<item.type>3, "float32") == 0) {
                                                                                fprintf(fp, "fcmpl\nifgt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }else if (strcmp($<item.type>1, "int32") == 0 && strcmp($<item.type>3, "int32") == 0) {
                                                                                fprintf(fp, "isub\nifgt L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }
                                                                }else if(strcmp($<item.value.s_val>2, "GEQ")==0){
                                                                        if (strcmp($<item.type>1, "float32") == 0 && strcmp($<item.type>3, "float32") == 0) {
                                                                                fprintf(fp, "fcmpl\nifge L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }else if (strcmp($<item.type>1, "int32") == 0 && strcmp($<item.type>3, "int32") == 0) {
                                                                                fprintf(fp, "isub\nifge L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }
                                                                }
                                                        }
;

equality_expression
        : relational_expression                                 {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | equality_expression equ_op relational_expression {if( strcmp($<item.type>1,$<item.type>3)!=0 ){
                                                                        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n"
                                                                        ,yylineno ,$<item.value.s_val>2, $<item.type>1,$<item.type>3);
                                                                }
                                                                $<item.type>$="bool";
                                                                printf("%s\n", $<item.value.s_val>2);
                                                                if(strcmp($<item.value.s_val>2, "EQL")==0){
                                                                        if (strcmp($<item.type>1, "float32") == 0 && strcmp($<item.type>3, "float32") == 0) {
                                                                                fprintf(fp, "fcmpl\nifeq L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++; 
                                                                                label_number++;
                                                                        }else if (strcmp($<item.type>1, "int32") == 0 && strcmp($<item.type>3, "int32") == 0) {
                                                                                fprintf(fp, "isub\nifeq L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++; 
                                                                                label_number++;
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "NEQ")==0){
                                                                        if (strcmp($<item.type>1, "float32") == 0 && strcmp($<item.type>3, "float32") == 0) {
                                                                                fprintf(fp, "fcmpl\nifne L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }else if (strcmp($<item.type>1, "int32") == 0 && strcmp($<item.type>3, "int32") == 0) {
                                                                                fprintf(fp, "isub\nifne L_cmp_%d\niconst_0\ngoto L_cmp_%d\nL_cmp_%d:\niconst_1\nL_cmp_%d:\n", label_number, label_number + 1, label_number, label_number + 1);
                                                                                label_number++;
                                                                                label_number++;
                                                                        }
                                                                }
                                                        }
;

logical_and_expression
        : equality_expression                                   {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | logical_and_expression LAND equality_expression {
                                                                if( !strcmp($<item.type>1,"int32")){
                                                                        printf("error:%d: invalid operation: (operator LAND not defined on %s)\n",yylineno,$<item.type>1);
                                                                }
                                                                else if( !strcmp($<item.type>3,"int32")){
                                                                        printf("error:%d: invalid operation: (operator LAND not defined on %s)\n",yylineno,$<item.type>3);
                                                                }
                                                                $<item.type>$="bool";
                                                                printf("LAND\n");
                                                                fprintf(fp, "iand\n");                                                   
                                                        }


;
logical_or_expression
        : logical_and_expression                                {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | logical_or_expression LOR logical_and_expression {
                                                                if( !strcmp($<item.type>1,"int32")){
                                                                        printf("error:%d: invalid operation: (operator LOR not defined on %s)\n",yylineno,$<item.type>1);
                                                                }
                                                                else if( !strcmp($<item.type>3,"int32")){
                                                                        printf("error:%d: invalid operation: (operator LOR not defined on %s)\n",yylineno,$<item.type>3);
                                                                }
                                                                $<item.value>$=$<item.value>3;
                                                                $<item.type>$="bool";
                                                                printf("LOR\n");
                                                                fprintf(fp, "ior\n");
                                                           }
;

assignment_expression
        : logical_or_expression                                 {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
        | UnaryExpr assign_op assignment_expression {           if(!$<item.type>1){ $<item.type>1="ERROR"; }
                                                                if( strcmp($<item.type>1,$<item.type>3)!=0 ){
                                                                        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n"
                                                                        ,yylineno ,$<item.value.s_val>2, $<item.type>1,$<item.type>3);
                                                                }

                                                                $<item.value>$=$<item.value>1; // or $<>3?
                                                                $<item.type>$=$<item.type>1;
                                                                printf("%s\n", $<item.value.s_val>2);
                                                                
                                                                if(strcmp($<item.value.s_val>2, "ASSIGN")==0){
                                                                        if(strcmp($<item.type>1, "int32") == 0){
                                                                               fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                        else if(strcmp($<item.type>1, "float32") == 0){
                                                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "string") == 0){
                                                                                fprintf(fp, "astore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "bool") == 0){
                                                                                fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "ADD")==0){
                                                                        if (strcmp("float32", $<item.type>3) == 0){
                                                                                fprintf(fp, "fadd\n");
                                                                        }else if (strcmp("int32", $<item.type>3) == 0){
                                                                                fprintf(fp, "iadd\n");
                                                                        }

                                                                        if(strcmp($<item.type>1, "int32") == 0){
                                                                               fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                        else if(strcmp($<item.type>1, "float32") == 0){
                                                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "string") == 0){
                                                                                fprintf(fp, "astore\n");
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "SUB")==0){
                                                                        if (strcmp("float32", $<item.type>3) == 0){
                                                                                fprintf(fp, "fsub\n");
                                                                        }else if (strcmp("int32", $<item.type>3) == 0){
                                                                                fprintf(fp, "isub\n");
                                                                        }

                                                                        if(strcmp($<item.type>1, "int32") == 0){
                                                                               fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                        else if(strcmp($<item.type>1, "float32") == 0){
                                                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "string") == 0){
                                                                                fprintf(fp, "astore\n");
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "MUL")==0){
                                                                        if (strcmp("float32", $<item.type>3) == 0){
                                                                                fprintf(fp, "fmul\n");
                                                                        }else if (strcmp("int32", $<item.type>3) == 0){
                                                                                fprintf(fp, "imul\n");
                                                                        }

                                                                        if(strcmp($<item.type>1, "int32") == 0){
                                                                               fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                        else if(strcmp($<item.type>1, "float32") == 0){
                                                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "string") == 0){
                                                                                fprintf(fp, "astore\n");
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "QUO")==0){
                                                                        if (strcmp("float32", $<item.type>3) == 0){
                                                                                fprintf(fp, "fdiv\n");
                                                                        }else if (strcmp("int32", $<item.type>3) == 0){
                                                                                fprintf(fp, "idiv\n");
                                                                        }

                                                                        if(strcmp($<item.type>1, "int32") == 0){
                                                                               fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                        else if(strcmp($<item.type>1, "float32") == 0){
                                                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "string") == 0){
                                                                                fprintf(fp, "astore\n");
                                                                        }
                                                                }
                                                                else if(strcmp($<item.value.s_val>2, "REM")==0){
                                                                        fprintf(fp, "irem\n");

                                                                        if(strcmp($<item.type>1, "int32") == 0){
                                                                               fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>1) -> address); 
                                                                        }
                                                                        else if(strcmp($<item.type>1, "float32") == 0){
                                                                                fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>1) -> address);
                                                                        }
                                                                        else if(strcmp($<item.type>1, "string") == 0){
                                                                                fprintf(fp, "astore\n");
                                                                        }
                                                                }
                                                }
;

Expression
        : assignment_expression                                 {$<item.type>$=$<item.type>1; $<item.value>$=$<item.value>1;}
;

rel_op
        : '<'   { $<item.value.s_val>$="LTR"; }
        | LEQ   { $<item.value.s_val>$="LEQ"; }
        | '>'   { $<item.value.s_val>$="GTR"; }
        | GEQ   { $<item.value.s_val>$="GEQ"; }
;

equ_op
        : EQ    {$<item.value.s_val>$="EQL";}
        | NEQ   {$<item.value.s_val>$="NEQ";}
;

add_op
        : '+'   { $<item.value.s_val>$="ADD"; }
        | '-'   { $<item.value.s_val>$="SUB"; }
;

mul_op
        : '*'   { $<item.value.s_val>$="MUL"; }   
        | '/'   { $<item.value.s_val>$="QUO"; }
        | '%'   { $<item.value.s_val>$="REM"; }
;

unary_op
        : '+'  { $<item.value.s_val>$="POS"; }
        | '-'  { $<item.value.s_val>$="NEG"; }
        | '!'  { $<item.value.s_val>$="NOT";    fprintf(fp, "iconst_1\n"); }
;

assign_op
        : '='   { $<item.value.s_val>$="ASSIGN"; }
        | ADD_ASSIGN { $<item.value.s_val>$="ADD"; }
        | SUB_ASSIGN { $<item.value.s_val>$="SUB"; }
        | MUL_ASSIGN { $<item.value.s_val>$="MUL"; }
        | DIV_ASSIGN { $<item.value.s_val>$="QUO"; }
        | MOD_ASSIGN { $<item.value.s_val>$="REM"; }
;

PrimaryExpr
        : Operand       {$<item.value>$ = $<item.value>1; $<item.type>$=$<item.type>1; }
        | ConversionExpr{$<item.value>$ = $<item.value>1; $<item.type>$=$<item.type>1;}
;

Operand
        : Literal       { $<item.value>$ = $<item.value>1; $<item.type>$ = $<item.type>1;}
        | IdSet              {$<item.value>$ = $<item.value>1; $<item.type>$ = $<item.type>1;}
        | '(' Expression ')' {$<item.value>$ = $<item.value>1; $<item.type>$ = $<item.type>1;}
;

IdSet 
        : IDENT {
                        $<item.value>$ = $<item.value>1;
                        symtable_type* tmp_table = lookup_symbol($<item.value.s_val>1);
                        if (!tmp_table){
                                printf("error:%d: undefined: %s\n", yylineno+1, $<item.value.s_val>1);
                                $<item.type>$ = "ERROR";
                        }
                        else{
                                /// printf("IDENT (name=%s, address=%d)\n",$<item.value.s_val>1,tmp_table->address);
				$<item.type>$ = tmp_table->type;
                        	if(strcmp(tmp_table->type,"float32")==0){
					fprintf(fp,"fload %d\n", tmp_table->address);
				}
				else if(strcmp(tmp_table->type, "int32")==0){
					fprintf(fp,"iload %d\n", tmp_table->address);
				}
				else if(strcmp(tmp_table->type, "bool")==0){
					fprintf(fp, "iload %d\n", tmp_table->address); // there is no bload
				}
				else if(strcmp(tmp_table->type, "string")==0){
					fprintf(fp, "aload %d\n", tmp_table->address);
				}
			}
          }
        | IDENT '(' CallParaList ')' {
                                $<item.value>$ = $<item.value>1;
                                $<item.type>$ = "func";
                                char* temp_sig_str = (char *)malloc(sizeof(char)*10);
                                temp_sig_str = find_para($<item.value.s_val>1);
                                printf("call: %s%s\n", $<item.value.s_val>1, temp_sig_str);
                                fprintf(fp, "invokestatic Main/%s%s\n", $<item.value.s_val>1, temp_sig_str);
                        }
;

CallParaList
        :
        | Operand
        | CallParaList ',' Operand
;

Literal
        : INT_LIT       {
                                printf("INT_LIT %d\n",         $<item.value.i_val>$);
                                fprintf(fp, "ldc %d\n", $<item.value.i_val>1);
				$<item.value>$= $<item.value>1;
                                $<item.type>$ = "int32";
                        }
        | FLOAT_LIT     {       printf("FLOAT_LIT %f\n",       $<item.value.f_val>$);
                                fprintf(fp, "ldc %f\n", $<item.value.f_val>1);
				$<item.value>$= $<item.value>1;
                                $<item.type>$ = "float32";
                         }

        | BOOL_LIT      {
                                //if($<item.value.b_val>$ == true) printf("TRUE 1\n");
                                //else printf("FALSE 0\n");
				fprintf(fp, "%s\n", $<item.value.b_val>1? "iconst_1" : "iconst_0");
                                $<item.value>$= $<item.value>1;
                                $<item.type>$ = "bool";
                        }
        | '"' STRING_LIT '"'{
                                fprintf(fp, "ldc \"%s\"\n", $<item.value.s_val>2);
				
				$<item.value>$= $<item.value>2;
                                $<item.type>$ = "string";
                        }
;

ConversionExpr
        : Type '(' Expression ')' {
                if (strcmp($<item.type>3, "float32") == 0 && strcmp($<item.value.s_val>1, "int32") == 0){
                        printf("f2i\n");
                        fprintf(fp,"f2i\n");
                        $<item.type>$ = "int32";
                }
                else if (strcmp($<item.type>3, "int32") == 0 && strcmp($<item.value.s_val>1, "float32") == 0){
                        printf("i2f\n");
                        fprintf(fp, "i2f\n");
                        $<item.type>$ = "float32";
                }
                }
;

Statement
        : DeclarationStmt NEWLINE
        | SimpleStmt NEWLINE
        | Block
        | IfStmt
        | ForStmt
        | SwitchStmt
        | CaseStmt
        | PrintStmt NEWLINE
        | NEWLINE
;

SimpleStmt
        : ExpressionStmt
;

DeclarationStmt
        : VAR IDENT Type        { symtable_type* tem_table = lookup_symbol($<item.value.s_val>2);
                                        if(tem_table && tem_table->level == global_level){
                                                printf("error:%d: %s redeclared in this block. previous declaration at line %d\n"
                                                        ,yylineno, $<item.value.s_val>2, tem_table -> lineno);
                                                insert_symbol($<item.value.s_val>2, $<item.value.s_val>3, "-", 0);
                                        }
                                        else{ 
                                                insert_symbol($<item.value.s_val>2, $<item.value.s_val>3, "-", 0); 
                                                if(strcmp($<item.value.s_val>3 , "int32") == 0){
                                                        fprintf(fp, "ldc 0\n");
                                                	fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                                else if(strcmp($<item.value.s_val>3, "float32") == 0){
                                                        fprintf(fp, "ldc 0.0\n");
                                                        fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                                else if(strcmp($<item.value.s_val>3, "string") == 0){
                                                        fprintf(fp, "ldc \"\"\n");
                                                       	fprintf(fp, "astore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                                else if(strcmp($<item.value.s_val>3, "bool") == 0){
                                                        fprintf(fp, "ldc 0\n");
                                                        fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                        }
                                }     
        | VAR IDENT Type '=' Expression { symtable_type* tem_table = lookup_symbol($<item.value.s_val>2);
                                        if(tem_table && tem_table->level == global_level){
                                                printf("error:%d: %s redeclared in this block. previous declaration at line %d\n"
                                                        ,yylineno, $<item.value.s_val>2, tem_table -> lineno);
                                                insert_symbol($<item.value.s_val>2, $<item.value.s_val>3, "-", 0);
                                        }
                                        else{ 
						insert_symbol($<item.value.s_val>2, $<item.value.s_val>3, "-", 0); 
						if(strcmp($<item.value.s_val>3 , "int32") == 0){
                                                	fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                                else if(strcmp($<item.value.s_val>3, "float32") == 0){
                                                        fprintf(fp, "fstore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                                else if(strcmp($<item.value.s_val>3, "string") == 0){
                                                       	fprintf(fp, "astore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
                                                else if(strcmp($<item.value.s_val>3, "bool") == 0){
                                                        fprintf(fp, "istore %d\n", lookup_symbol($<item.value.s_val>2) -> address);
                                                }
					}
					
					}
;


ExpressionStmt
        : Expression
;

Block
        : BlockUp StatementList '}' {dump_symbol();}
;
BlockUp
        : '{' { create_symbol();}

;

StatementList 
        : Statement StatementList
        | Statement
;

IfStmt
        : IF Condition IfBlock		{fprintf(fp, "L_if_exit:\n");}
        | IF Condition IfBlock ELSE IfStmt
        | IF Condition IfBlock ELSE Block
;

IfBlock
	: IfBlockUp StatementList '}' {dump_symbol();}

;

IfBlockUp
	: '{' { create_symbol(); fprintf(fp, "ifeq L_if_exit\n");}
;

Condition
        : Expression { if (strcmp($<item.type>1, "bool")!=0){
                                printf("error:%d: non-bool (type %s) used as for condition\n",yylineno+1,$<item.type>1);
                        }
                     }
;

ForStmt
        : ForBegin ForClause ForBlock { fprintf(fp, "goto L_for_begin\n"); fprintf(fp, "L_for_exit:\n");}
        | ForBegin Condition ForBlock { fprintf(fp, "goto L_for_begin\n"); fprintf(fp, "L_for_exit:\n");}
;

ForBegin
	: FOR { fprintf(fp, "L_for_begin:\n"); }
;

ForBlock
	: ForBlockUp StatementList '}' {dump_symbol();}
;

ForBlockUp
	 : '{' { create_symbol(); fprintf(fp, "ifeq L_for_exit\n"); }

ForClause
        : InitStmt ';' Condition ';' PostStmt
;

InitStmt
        : SimpleStmt
;

PostStmt
        : SimpleStmt
;

SwitchStmt
        : SWITCH Expression SwitchBlockUp StatementList '}' {
                                                dump_symbol();
                                                fprintf(fp, "L_switch_begin_%d:\n", switch_num);
                                                fprintf(fp, "lookupswitch\n");
                                                for(int i = continue_num ; i > 0 ; i-- ){
                                                        if (i == 1){
                                                                fprintf(fp, "default: L_case_%d\n", case_num);
                                                        }
                                                        else{
                                                                fprintf(fp,"%d: L_case_%d\n", case_num-i+1 , case_num-i+1);
                                                        }
                                                }
                                                fprintf(fp, "L_switch_end_%d:\n", switch_num);
                                                // fprintf(fp, "return\n");
                                                switch_num ++;
                                                continue_num = 0;
                                }
;

SwitchBlockUp
        : '{'           { create_symbol(); fprintf(fp, "goto L_switch_begin_%d\n", switch_num); }

CaseStmt
        : CaseUp Block          { fprintf(fp, "goto L_switch_end_%d\n", switch_num); dump_symbol();}
        | DeafaultUp Block         { fprintf(fp, "goto L_switch_end_%d\n", switch_num); dump_symbol();}
;

DeafaultUp
        : DEFAULT {             create_symbol();
                                printf("case %d\n", case_num + 1);
                                fprintf(fp, "L_case_%d:\n", case_num + 1);
                                case_num ++;
                                continue_num ++;
                  }

CaseUp
        : CASE INT_LIT  {       create_symbol();
                                printf("case %d\n", $<item.value.i_val>2);
                                fprintf(fp, "L_case_%d:\n", $<item.value.i_val>2);
                                case_num =  $<item.value.i_val>2;
                                continue_num ++;
                        }
;

ReturnType
        :               {funct_parameterReturn = (char*)malloc(sizeof(char)*1);
                         funct_parameterReturn[0] = 'V';
                         funct_parameter = (char*)malloc(sizeof(funct_parameterUp) + sizeof(funct_parameterIn) + sizeof(funct_parameterDown) + sizeof(funct_parameterReturn) + 1);
                         strcpy(funct_parameter, funct_parameterUp);
                         strcat(funct_parameter, funct_parameterIn);
                         strcat(funct_parameter, funct_parameterDown);
                         strcat(funct_parameter, funct_parameterReturn);
                         insert_symbol(str_funct_name,"func",funct_parameter, 0);
                         printf("func_signature: %s\n",funct_parameter);
                         if (strcmp(str_funct_name, "main") == 0){
				 fprintf(fp, ".method public static main([Ljava/lang/String;)V\n");
                                 fprintf(fp, ".limit stack 100\n");
                                 fprintf(fp, ".limit locals 100\n");
                         }
                         else{
				 fprintf(fp, ".method public static %s%s\n", str_funct_name, funct_parameter);
                                 fprintf(fp, ".limit stack 20\n");
                                 fprintf(fp, ".limit locals 20\n");
                         }
                        }
        | Type          {
                         funct_parameterReturn  = (char *)malloc(sizeof(char)*2);
                         funct_parameterReturn[1] = '\0';
                         funct_parameterReturn[0] = toupper($<item.value.s_val>1[0]);
                         funct_parameter = (char*)malloc(sizeof(funct_parameterUp) + sizeof(funct_parameterIn) + sizeof(funct_parameterDown) + sizeof(funct_parameterReturn) + 1);
                         strcpy(funct_parameter, funct_parameterUp);
                         strcat(funct_parameter, funct_parameterIn);
                         strcat(funct_parameter, funct_parameterDown);
                         strcat(funct_parameter, funct_parameterReturn);
                         insert_symbol(str_funct_name,"func",funct_parameter, 0);
                        // printf("func_signature: %s\n",funct_parameter);
                         fprintf(fp, ".method public static %s%s\n", str_funct_name, funct_parameter);
                         if (strcmp(str_funct_name, "main") == 0){
                                 fprintf(fp, ".limit stack 100\n");
                                 fprintf(fp, ".limit locals 100\n");
      			 }
                         else{
                                 fprintf(fp, ".limit stack 20\n");
                                 fprintf(fp, ".limit locals 20\n");
                         }
                        }

Type
        : INT           {$<item.value.s_val>$ = "int32";}
        | FLOAT         {$<item.value.s_val>$ = "float32";}
        | STRING        {$<item.value.s_val>$ = "string";}
        | BOOL          {$<item.value.s_val>$ = "bool";}
;

ParameterList
        :               { $<item.value.s_val>$ = ""; }
        | IDENT Type    {       char temp_str[2];
                                temp_str[1] = '\0';
                                temp_str[0] = toupper($<item.value.s_val>2[0]);
                                $<item.value.s_val>$ = temp_str;
                                //$<item.value.s_val>$ = $<item.value.s_val>1;
                                printf("param %s, type: %c\n", $<item.value.s_val>1,toupper($<item.value.s_val>2[0]));
                                insert_symbol($<item.value.s_val>1,$<item.value.s_val>2,"-", 1);
                        }
        
        | ParameterList ',' IDENT Type  {       char* extrac = (char *)malloc(sizeof($<item.value.s_val>4));
                                                strcpy(extrac, $<item.value.s_val>4);
                                                printf("param %s, type: %c\n", $<item.value.s_val>3,toupper($<item.value.s_val>4[0]));
                                                insert_symbol($<item.value.s_val>3,extrac,"-", 1);
                                                char* temp_para_str = (char *)malloc(sizeof(char)*2);
                                                temp_para_str[1] = '\0';
                                                temp_para_str[0] = toupper($<item.value.s_val>4[0]);

                                                char* combine = (char *)malloc(sizeof($<item.value.s_val>1) + sizeof(temp_para_str) + 1);
                                                strcpy(combine, $<item.value.s_val>1);
                                                strcat(combine, temp_para_str);
                                                $<item.value.s_val>$ = combine;
                                        }
                                         
;

ReturnStmt
        : RETURN Expression NEWLINE { 
					printf("%creturn\n",$<item.type>2[0]);
					fprintf(fp, "%creturn\n", $<item.type>2[0]);
				}
        | RETURN NEWLINE       {
				printf("return\n");
				fprintf(fp,"return\n");
			}
	|	        {
                                printf("return\n");
                                fprintf(fp,"return\n");
                        }
	
;

PrintStmt
        : PRINT '(' Expression ')'      {
                                                printf("PRINT %s\n", $<item.type>3);
                                                if (strcmp("float32", $<item.type>3) == 0){
                                                        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(F)V\n");
                                                }else if (strcmp("int32", $<item.type>3) == 0){
                                                        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(I)V\n");
                                                }else if (strcmp("string", $<item.type>3) == 0){
                                                        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
                                                }else if (strcmp("bool", $<item.type>3) == 0){
                                                        fprintf(fp, "ifne L_cmp_%d\nldc \"false\"\ngoto L_cmp_%d\nL_cmp_%d:\nldc \"true\"\nL_cmp_%d:\ngetstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n", label_number, label_number + 1, label_number, label_number + 1);
                                                        label_number++; label_number++;
                                                }
                                        }
        | PRINTLN '(' Expression ')'    {
                                                printf("PRINTLN %s\n", $<item.type>3);
                                                if (strcmp("float32", $<item.type>3) == 0){
                                                        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/println(F)V\n");
                                                }else if (strcmp("int32", $<item.type>3) == 0){
                                                        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/println(I)V\n");
                                                }else if (strcmp("string", $<item.type>3) == 0){
                                                        fprintf(fp, "getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
                                                }else if (strcmp("bool", $<item.type>3) == 0){
                                                        fprintf(fp, "ifne L_cmp_%d\nldc \"false\"\ngoto L_cmp_%d\nL_cmp_%d:\nldc \"true\"\nL_cmp_%d:\ngetstatic java/lang/System/out Ljava/io/PrintStream;\nswap\ninvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n", label_number, label_number + 1, label_number, label_number + 1);
                                                        label_number++; label_number++;
                                                }
                                        }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }
	
    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fp = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");
	printf("hello 817\n");
    /* Symbol table init */
    // Add your code
    
    // symtable_stack_type* stack_head = NULL; // instructe here?

    yylineno = 0;
    yyparse();
	printf("hello 825\n");
    /* Symbol table dump */
    // Add your code

	printf("Total lines: %d\n", yylineno);
    fclose(fp);
    fclose(yyin);

    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}
/* Symbol Table */

// symtable_stack_type* stack_head = NULL;

static void create_symbol() {
        // create a empty stack and set property
        global_level++;
        symtable_stack_type* tmp_stack = (symtable_stack_type *)malloc(sizeof(symtable_stack_type));
        tmp_stack -> table = NULL;
        tmp_stack -> level = global_level;
        // make it to be the head(newest) of current stack linked list
        tmp_stack -> next = stack_head;
        stack_head = tmp_stack;
        // print infomation
        printf("> Create symbol table (scope level %d)\n", global_level);
}
static void insert_symbol(char* name, char* type, char* Func_sig, int para_bool) {
        if(strcmp(type,"func")==0)
                printf("> Insert `%s` (addr: -1) to scope level %d\n", name, global_level-1);
        else
                printf("> Insert `%s` (addr: %d) to scope level %d\n", name, global_address, global_level);
        // Create a new table

        symtable_type* tmp_table = (symtable_type *)malloc(sizeof(symtable_type));

        tmp_table -> lineno = (strcmp(type, "func")==0 || (para_bool == 1))? yylineno+1 : yylineno ;
        tmp_table -> level = global_level;
        tmp_table -> address = (strcmp(type, "func")==0)? -1 : global_address;
        if (!(strcmp(type, "func")==0))
                global_address ++;

        tmp_table -> name = (char*) malloc (strlen(name) + 1);
        strcpy(tmp_table-> name, name);
        tmp_table -> func_sig = (char*)malloc(strlen(Func_sig) +1);
        strcpy(tmp_table->func_sig, Func_sig);
        tmp_table -> type = (char*)malloc(strlen(type) +1);
        strcpy(tmp_table->type, type);
        // Find the correct stack head
        symtable_stack_type* tmp_head = (symtable_stack_type*)malloc(0);
        if(strcmp(type,"func")==0)
                tmp_head = stack_head->next;
        else{
                tmp_head = stack_head;
        }
        // Make table to be the last one in head-stack
        if(!tmp_head->table){
                tmp_table -> index = 0;
                tmp_head -> table = tmp_table;
        }
        else{
                int last_index = 1;
                symtable_type* last_table = tmp_head -> table;
                while(last_table -> next){
                        last_table = last_table -> next;
                        last_index ++;
                }
                tmp_table -> index = last_index;
                last_table -> next = tmp_table;
                //tmp_tabletmp_table -> index = last_index;
        }
}
static symtable_type* lookup_symbol(char * name) {
        // from stack head
        symtable_stack_type* tmp_stack = stack_head;
        while(tmp_stack){
                // from the first table in this stack
                symtable_type* tmp_table = tmp_stack -> table;
                while(tmp_table){
                        if(strcmp(tmp_table -> name,name)==0){
                                return tmp_table;
                        }
                        tmp_table = tmp_table -> next;
                }
                tmp_stack = tmp_stack -> next;
        }
        return 0;
}

static char* find_para(char * name){
        // from stack head
        symtable_stack_type* tmp_stack = stack_head;
        while(tmp_stack){
                // from the first table in this stack
                symtable_type* tmp_table = tmp_stack -> table;
                while(tmp_table){
                        if(strcmp(tmp_table -> name,name)==0){
                                return tmp_table -> func_sig;
                        }
                        tmp_table = tmp_table -> next;
                }
                tmp_stack = tmp_stack -> next;
        }
        return 0;

}
static void dump_symbol() {
        printf("\n> Dump symbol table (scope level: %d)\n", global_level);
        printf("%-10s%-10s%-10s%-10s%-10s%-10s\n","Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
        // print all table in head stack
        symtable_type* tmp_table = stack_head -> table;
        while(tmp_table){
                printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",tmp_table->index, tmp_table->name, tmp_table->type, tmp_table->address, tmp_table->lineno, tmp_table->func_sig );
                tmp_table = tmp_table->next;
        }
        printf("\n");
        // change head by -1
        stack_head = stack_head-> next;
        global_level --;
}
   
