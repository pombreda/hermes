#include <pcre.h>
#include <stdio.h>
#include <string.h>
#include "parser_common.h"
#include "{{prefix}}lexer.h"

/* index with {{prefix.upper()}}TERMINAL_E */
static char * {{prefix}}morphemes[] = {
{% for terminal in sorted(lexer.terminals, key=lambda x: x.id) %}
  "{{terminal.string}}", /* {{terminal.id}} */
{% endfor %}
};

/* START USER CODE */
{{lexer.code}}
/* END USER CODE */

static LEXER_REGEX_T *** lexer = NULL;

static LEXER_MATCH_T * default_action(
    void * context,
    int mode,
    char ** match_groups,
    TERMINAL_T * terminal,
    int line,
    int col)
{
    LEXER_MATCH_T * match = calloc(1, sizeof(LEXER_MATCH_T));
    match->match_length = strlen(match_groups[0]);
    match->tokens = calloc(2, sizeof(TOKEN_T*));
    match->tokens[0] = calloc(1, sizeof(TOKEN_T)); //1-800-732-3400
    match->tokens[0]->lineno = line;
    match->tokens[0]->colno = col;
    match->tokens[0]->source_string = strdup(match_groups[0]);
    match->tokens[0]->resource = "blah";
    match->tokens[0]->terminal = calloc(1, sizeof(TERMINAL_T));
    memcpy(match->tokens[0]->terminal, terminal, sizeof(TERMINAL_T));
    match->context = context;
    match->mode = mode;
    return match;
}

void {{prefix}}lexer_init() {
    LEXER_REGEX_T * r;
    if (lexer != NULL) {
        return;
    }
    lexer = calloc({{len(lexer.keys())}} + 1, sizeof(LEXER_REGEX_T **));
{% for mode, regex_list in lexer.items() %}
    lexer[{{prefix.upper()}}LEXER_{{mode.upper()}}_MODE_E] = calloc({{len(regex_list)}} + 1, sizeof(LEXER_REGEX_T *));
  {% for i, regex in enumerate(regex_list) %}
    r = calloc(1, sizeof(LEXER_REGEX_T));
    r->regex = pcre_compile({{regex.regex}}, 0, &r->pcre_errptr, &r->pcre_erroffset, NULL);
    r->pattern = {{regex.regex}};
    r->terminal = calloc(1, sizeof(TERMINAL_T));
    r->terminal->string = {{'"' + regex.terminal.string.lower() + '"' if regex.terminal else 'NULL'}};
    r->terminal->id = {{regex.terminal.id}};
    r->match_func = {{regex.function if regex.function else 'default_action'}};
    lexer[{{prefix.upper()}}LEXER_{{mode.upper()}}_MODE_E][{{i}}] = r;
  {% endfor %}
{% endfor %}
}

int {{prefix}}lexer_has_errors() {
    int i, j;
    for (int i = 0; lexer[i]; i++) {
        for (j = 0; lexer[i][j]; j++) {
            if (lexer[i][j]->regex == NULL) {
                return 1;
            }
        }
    }
    return 0;
}

void {{prefix}}lexer_print_errors() {
    int i, j, k;
    for (int i = 0; lexer[i]; i++) {
        for (j = 0; lexer[i][j]; j++) {
            if (lexer[i][j]->regex == NULL) {
                char * prefix = "Error compiling regex: ";
                printf("%s%s\n", prefix, lexer[i][j]->pattern);
                for (k = 0; k < strlen(prefix) + lexer[i][j]->pcre_erroffset - 1; k++) {
                    printf(" ");
                }
                printf("^\n");
                printf("%s\n\n", lexer[i][j]->pcre_errptr);
            }
        }
    }
}

void {{prefix}}lexer_destroy() {
    int i, j;
    for (int i = 0; lexer[i]; i++) {
        for (j = 0; lexer[i][j]; j++) {
            pcre_free(lexer[i][j]->regex);
            free(lexer[i][j]->terminal);
            free(lexer[i][j]);
        }
    }
    free(lexer);
    lexer = NULL;
}

static void update_line_col(char * match, int length, int * line, int * col) {
    int newline_count = 0, i;
    for (i = 0; i < length; i++) {
        if (match[i] == '\n') {
            *line += 1;
            *col = 0;
        } else {
            *col += 1;
        }
    }
}

static char * get_line(char * s, int line) {
    char * p, * start, * rval;
    int current_line = 1, length = 0;
    if ( line < 1 ) {
        return NULL;
    }
    for( p = start = s; *p; p++ ) {
        if (*p == '\n') {
            if ( line == current_line ) {
                break;
            }
            current_line++;
            length = 0;
            start = p + 1;
        } else {
            length++;
        }
    }
    if (current_line < line) {
        return NULL;
    }
    rval = calloc(length + 1, sizeof(char));
    strncpy(rval, start, length);
    return rval;
}

static void unrecognized_token(char * string, int line, int col, char * message) {
    char * bad_line = get_line(string, line);
    char * spaces = calloc(col+1, sizeof(char));
    memset(spaces, ' ', col-1);
    sprintf(message, "Unrecognized token on line %d, column %d:\n\n%s\n%s^",
        line, col, bad_line, spaces
    );
    free(spaces);
    free(bad_line);
}

static LEXER_MATCH_T * next(char * string, {{prefix.upper()}}LEXER_MODE_E mode, void * context, int line, int col) {
    int error_offset, rc, i, j;
    int ovector_count = 30;
    int ovector[ovector_count];
    char ** match_groups;
    LEXER_MATCH_T * match;
    for (i = 0; lexer[mode][i]; i++) {
        rc = pcre_exec(lexer[mode][i]->regex, NULL, string, strlen(string), 0, 0, ovector, ovector_count);
        if (rc >= 0) {
            lexer_match_function match_func = lexer[mode][i]->match_func != NULL ? lexer[mode][i]->match_func : default_action;

            match_groups = calloc(rc+1, sizeof(char *));
            for (j = 0; j < rc; j++) {
                char *substring_start = string + ovector[2*j];
                int substring_length = ovector[2*j+1] - ovector[2*j];
                match_groups[j] = calloc(substring_length+1, sizeof(char));
                strncpy(match_groups[j], substring_start, substring_length);
            }

            match = match_func(context, mode, match_groups, lexer[mode][i]->terminal, line, col);

            for (j = 0; match_groups[j]; j++) {
                free(match_groups[j]);
            }
            free(match_groups);
            return match;
        }
    }
    return NULL;
}

TOKEN_T ** {{prefix}}lex(char * string, void * context, char * error) {
    int line = 1, col = 1, i;
    {{prefix.upper()}}LEXER_MODE_E mode = {{prefix.upper()}}LEXER_DEFAULT_MODE_E;
    char * string_current = string;
    int parsed_tokens_size = 100;
    int parsed_tokens_index = 0;
    TOKEN_T ** parsed_tokens = calloc(parsed_tokens_size, sizeof(TOKEN_T *));

    while (strlen(string_current)) {
        LEXER_MATCH_T * match = next(string_current, mode, context, line, col);

        if (match == NULL || match->match_length == 0) {
            unrecognized_token(string, line, col, error);
            free(parsed_tokens);
            return NULL;
        }

        for (i = 0; match->tokens && match->tokens[i]; i++) {
            if (parsed_tokens_index + 1 == parsed_tokens_size) {
                parsed_tokens_size += 100;
                parsed_tokens = realloc(parsed_tokens, parsed_tokens_size * sizeof(TOKEN_T *));
            }
            parsed_tokens[parsed_tokens_index++] = match->tokens[i];
        }
        update_line_col(string_current, match->match_length, &line, &col);

        mode = match->mode;
        string_current += match->match_length;
    }
    parsed_tokens[parsed_tokens_index++] = NULL;
    return parsed_tokens;
}

/*def lex(file_or_path, debug=False):
    if isinstance(file_or_path, str):
        try:
            with open(file_or_path) as fp:
                contents = fp.read()
        except FileNotFoundError:
            contents = file_or_path
    elif hasattr(file_or_path, 'read') and hasattr(file_or_path, 'close'):
        contents = file_or_path.read()
        file_or_path.close()

    lexer = HermesLexer()
    return TokenStream(lexer.lex(contents, debug))
*/